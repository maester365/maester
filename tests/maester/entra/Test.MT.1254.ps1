function Get-MtTenantConfigurationMonitorInstance {
    <#
    .SYNOPSIS
    Returns one MT.1254 instance per Tenant Configuration Management monitor.

    .DESCRIPTION
    Instance source of the MT.1254 family. Reads the configuration monitors of the tenant and returns one instance
    per monitor, keyed by the monitor id, with the monitor as its data. Without monitors there are no instances and
    the family is skipped.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    # Tenant Configuration Management is only available in the worldwide Microsoft Graph service.
    $graphEnvironment = (Get-MgContext).Environment
    if ($graphEnvironment -and $graphEnvironment -ne 'Global') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Tenant Configuration Management is not available in the $graphEnvironment cloud."
        return
    }

    try {
        $monitors = @(Invoke-MtGraphRequest -RelativeUri 'admin/configurationManagement/configurationMonitors' -ApiVersion v1.0 `
                -Select 'id', 'displayName', 'description', 'status', 'inactivationReason', 'monitorRunFrequencyInHours', 'mode', 'createdDateTime', 'lastModifiedDateTime', 'createdBy', 'lastModifiedBy' -ErrorAction Stop)
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -in @(401, 403)) {
            # The skip from the instance source skips the whole family, as the drift request does for one monitor.
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return
        }
        throw
    }

    foreach ($monitor in @($monitors | Where-Object { $_.id } | Sort-Object -Property displayName)) {
        $name = if ($monitor.displayName) { $monitor.displayName } else { $monitor.id }
        [pscustomobject]@{
            Id    = $monitor.id
            Title = "Tenant Configuration Management monitor '$name' reports no active configuration drift."
            Data  = $monitor
        }
    }
}

function Test-MtEntraTenantConfigurationDrift {
    <#
    .SYNOPSIS
    Checks that a Tenant Configuration Management monitor reports no active configuration drift.

    .DESCRIPTION
    Microsoft Entra Tenant Governance configuration management (Unified Tenant Configuration Management, UTCM)
    runs monitors that compare the tenant's settings across Entra, Exchange Online, Intune, Teams, Purview and
    Defender with a JSON configuration baseline. Each difference is reported as a configuration drift with the
    drifted properties and their current and desired values.

    The check is a family with one result per monitor. Each result fails when its monitor reports an active
    drift, and shows the monitor's status and latest run and one table per resource type. When the monitor
    reports no drift but is inactive, its last run failed, it is overdue, it has not run yet or its runs cannot
    be read, the result is Investigate. Without monitors, without the ConfigurationMonitoring.Read.All permission
    or outside the worldwide cloud the family is skipped.

    Learn more:
    https://learn.microsoft.com/entra/id-governance/tenant-governance/configuration-management

    .EXAMPLE
    Invoke-MtTest -Id MT.1254

    .LINK
    https://maester.dev/docs/tests/MT.1254
    #>
    [MaesterTest(
        Id = 'MT.1254',
        Title = 'Tenant Configuration Management monitors report no active configuration drift.',
        Product = 'entra',
        Feature = 'monitoring',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1484', 'T1556.009'),
        Control = ('nist-800-53-r5:CM-6', 'nist-800-53-r5:CM-2'),
        Service = 'Graph',
        Permission = 'Graph:Scope:ConfigurationMonitoring.Read.All',
        Cloud = ('Commercial', 'GCC'),
        Lifecycle = 'Preview',
        InstanceSource = 'Get-MtTenantConfigurationMonitorInstance',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The configuration monitor to check, supplied by the engine.
        $Instance,

        # Longest number of characters shown for a current or desired property value in the result.
        [ValidateRange(20, 1000)]
        [int] $MaximumValueLength = 80,

        # Maximum number of drifts listed for the monitor; the others are counted.
        [ValidateRange(1, 1000)]
        [int] $MaxDriftsPerMonitor = 50,

        # Maximum number of drifted properties listed for each resource; the others are counted.
        [ValidateRange(1, 100)]
        [int] $MaxPropertiesPerResource = 5
    )

    $monitor = $Instance.Data
    $nowUtc = (Get-Date).ToUniversalTime()
    $toUtc = {
        param($Value)
        if ($Value -is [datetime]) { return $Value.ToUniversalTime() }
        if ($Value -is [datetimeoffset]) { return $Value.UtcDateTime }
        $parsed = [datetimeoffset]::MinValue
        if ($Value -and [datetimeoffset]::TryParse("$Value", [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) {
            return $parsed.UtcDateTime
        }
        return $null
    }

    # The active drifts of every monitor are read once and served from the request cache to the other monitors.
    try {
        $drifts = @(Invoke-MtGraphRequest -RelativeUri 'admin/configurationManagement/configurationDrifts' -ApiVersion v1.0 `
                -Filter "status eq 'active'" `
                -Select 'id', 'monitorId', 'resourceType', 'baselineResourceDisplayName', 'resourceInstanceIdentifier', 'firstReportedDateTime', 'status', 'driftedProperties' `
                -ErrorAction Stop | Where-Object { $_.monitorId -eq $monitor.id })
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(401, 403)) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return $null
        }
        throw
    }

    $isActive = -not $monitor.status -or $monitor.status -eq 'active'
    $frequency = if ([int]$monitor.monitorRunFrequencyInHours -gt 0) { [int]$monitor.monitorRunFrequencyInHours } else { 6 }
    # A monitor is overdue when it has not started a run for more than two run intervals (plus an hour of slack).
    $overdueAfterHours = 2 * $frequency + 1

    # The latest run of the monitor. The runs of the last days are read once for all monitors: the start of the
    # window is a whole day, so every monitor with the same schedule sends the same request and the cache answers
    # it. The window always covers the overdue limit, so a monitor on a long schedule is not overdue for lack of data.
    $runLookbackDays = [int][math]::Max(7, [math]::Ceiling($overdueAfterHours / 24))
    $since = $nowUtc.Date.AddDays(-$runLookbackDays).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [cultureinfo]::InvariantCulture)
    $runsQuery = @{
        RelativeUri = 'admin/configurationManagement/configurationMonitoringResults'
        ApiVersion  = 'v1.0'
        ErrorAction = 'Stop'
    }
    $runsError = $null
    $runs = @()
    try {
        $runs = @(Invoke-MtGraphRequest @runsQuery -Filter "runInitiationDateTime ge $since" -QueryParameters @{ '$top' = '999' })
    } catch {
        Write-Verbose "Could not read the monitor runs since $($since): $($_.Exception.Message)"
        try {
            $runs = @(Invoke-MtGraphRequest @runsQuery)
        } catch {
            $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
            $message = ("$($_.Exception.Message)" -split '\r?\n')[0]
            if ($message.Length -gt 160) { $message = $message.Substring(0, 160) + '…' }
            $runsError = "$(if ($statusCode) { "HTTP $($statusCode): " })$message"
            Write-Verbose "Could not read the monitor runs: $runsError"
        }
    }
    $lastRun = $runs | Where-Object { $null -ne $_ -and $_.monitorId -eq $monitor.id } |
        Sort-Object -Property { & $toUtc $_.runInitiationDateTime } -Descending | Select-Object -First 1

    $lastRunStarted = if ($lastRun) { & $toUtc $lastRun.runInitiationDateTime } else { $null }
    # Without a run, the monitor is measured from its creation: a new monitor waits for its first run.
    $createdUtc = & $toUtc $monitor.createdDateTime
    $awaitingFirstRun = $isActive -and -not $runsError -and $null -eq $lastRun -and $createdUtc -and ($nowUtc - $createdUtc).TotalHours -le $overdueAfterHours
    # A run without a readable start time cannot show that the monitor ran on schedule.
    $isOverdue = $isActive -and -not $runsError -and -not $awaitingFirstRun -and ($null -eq $lastRun -or -not $lastRunStarted -or ($nowUtc - $lastRunStarted).TotalHours -gt $overdueAfterHours)
    # Only a confirmed successful run shows that the drift list is complete. failed, partiallySuccessful,
    # unknownFutureValue, a missing status or any status Microsoft Graph adds later needs investigation.
    $runNotSuccessful = $isActive -and -not $runsError -and $null -ne $lastRun -and "$($lastRun.runStatus)" -ne 'successful'

    $entraPortal = $__MtSession.AdminPortalUrl.Entra
    $escape = {
        param($Text)
        "$Text" -replace '\r?\n', ' ' -replace '\|', '\|'
    }
    $monitorUrl = "$($entraPortal)#view/Microsoft_Entra_TenantManagement/MonitorDetails.ReactView/monitorId/$($monitor.id)"
    # The Monitor results tab of Tenant Governance, filtered to this monitor by a JSON filter in the URL.
    $monitorFilter = [uri]::EscapeDataString((ConvertTo-Json -InputObject @{ monitorId = "$($monitor.id)" } -Compress)) -replace '\(', '%28' -replace '\)', '%29'
    $monitorResultsUrl = "$($entraPortal)#view/Microsoft_Entra_TenantManagement/InternalMonitor.ReactView/initialTab/monitorResults/monitorResultsFilterParams~/$monitorFilter"
    $monitorResultsLink = if ($entraPortal) { "📊 [Monitor results]($monitorResultsUrl)" } else { $null }
    $monitorName = Get-MtSafeMarkdown $(if ($monitor.displayName) { $monitor.displayName } else { $monitor.id })
    $monitorLink = if ($entraPortal) { "📡 [$monitorName]($monitorUrl)" } else { "📡 $monitorName" }

    $formatAge = {
        param([datetime] $Utc)
        $hours = ($nowUtc - $Utc).TotalHours
        if ($hours -lt 1) { 'less than an hour ago' } elseif ($hours -lt 48) { "$([int][math]::Floor($hours)) h ago" } else { "$([int][math]::Floor($hours / 24)) days ago" }
    }
    $runIcon = '❔'
    $runText = if (-not $isActive) {
        $runIcon = '⏸️'
        'Not running while the monitor is inactive'
    } elseif ($runsError) {
        'Unknown, the monitor runs could not be read'
    } elseif ($awaitingFirstRun) {
        $runIcon = '⏳'
        'No run yet since the monitor was created'
    } elseif ($null -eq $lastRun) {
        $runIcon = '⏰'
        "No run in the last $runLookbackDays days"
    } else {
        $runIcon, $runStatus = switch ($lastRun.runStatus) {
            'successful' { '✅', 'Successful' }
            'partiallySuccessful' { '⚠️', 'Partially successful' }
            'failed' { '❌', 'Failed' }
            default { '❔', "$($lastRun.runStatus)" }
        }
        $when = if ($lastRunStarted) { "$($lastRunStarted.ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)) UTC ($(& $formatAge $lastRunStarted))" } else { 'unknown time' }
        $lastRunCompleted = & $toUtc $lastRun.runCompletionDateTime
        $duration = if ($lastRunStarted -and $lastRunCompleted -and $lastRunCompleted -ge $lastRunStarted) {
            $minutes = ($lastRunCompleted - $lastRunStarted).TotalMinutes
            " · took $(if ($minutes -lt 1) { 'less than a minute' } else { "$([int][math]::Round($minutes)) min" })"
        } else { '' }
        $found = if ($null -ne $lastRun.driftsCount -and $lastRun.runStatus -ne 'failed') { " · found $([int]$lastRun.driftsCount) $(if ([int]$lastRun.driftsCount -eq 1) { 'drift' } else { 'drifts' })" } else { '' }
        "$runStatus · $when$duration$found$(if ($isOverdue) { ' · ⏰ **overdue**' })"
    }
    $formatIdentity = {
        param($IdentitySet)
        $who = if ($IdentitySet.user.userPrincipalName) { "👤 $($IdentitySet.user.userPrincipalName)" }
        elseif ($IdentitySet.user.displayName) { "👤 $($IdentitySet.user.displayName)" }
        elseif ($IdentitySet.application.displayName) { "🧩 $($IdentitySet.application.displayName)" }
        elseif ($IdentitySet.app.displayName) { "🧩 $($IdentitySet.app.displayName)" }
        else { $null }
        if ($who) { " by $(Get-MtSafeMarkdown $who)" } else { '' }
    }
    $formatChangeDate = {
        param($Value)
        $date = & $toUtc $Value
        if (-not $date) { return $null }
        "$($date.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)) ($(& $formatAge $date))"
    }

    # microsoft.<workload>.<resource> → a workload icon and name; the full type stays visible for searching the docs.
    $workloads = @{
        entra                 = @{ Icon = '🆔'; Name = 'Entra ID' }
        exchange              = @{ Icon = '📧'; Name = 'Exchange Online' }
        intune                = @{ Icon = '💻'; Name = 'Intune' }
        teams                 = @{ Icon = '💬'; Name = 'Teams' }
        securityandcompliance = @{ Icon = '🔒'; Name = 'Purview' }
        purview               = @{ Icon = '🔒'; Name = 'Purview' }
        defender              = @{ Icon = '🛡️'; Name = 'Defender' }
    }
    $formatResourceType = {
        param([string] $ResourceType)
        $workload = ($ResourceType -split '\.')[1]
        $info = if ($workload -and $workloads.ContainsKey($workload)) { $workloads[$workload] } else { @{ Icon = '🧩'; Name = $(if ($workload) { $workload } else { 'Unknown workload' }) } }
        "$($info.Icon) $($info.Name) · ``$ResourceType``"
    }
    # Entra resources with an object id link to the object itself, which also lists them as affected objects.
    # Every other resource links to the monitor, where the drift can be reviewed.
    $sharedLinkTemplates = (Get-MtPortalLinkTemplate).LinkTemplates
    $objectLinkTemplates = @{
        'microsoft.entra.conditionalaccesspolicy' = @{ Key = 'Id'; Template = $sharedLinkTemplates.ConditionalAccess }
        'microsoft.entra.group'                   = @{ Key = 'Id'; Template = $sharedLinkTemplates.Groups }
        'microsoft.entra.user'                    = @{ Key = 'Id'; Template = $sharedLinkTemplates.Users }
        'microsoft.entra.serviceprincipal'        = @{ Key = 'Id'; Template = $sharedLinkTemplates.ServicePrincipals }
        # App registrations open by appId; the shared templates address objects by object id.
        'microsoft.entra.application'             = @{ Key = 'AppId'; Template = "$($entraPortal)#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/{0}" }
    }
    $resourceKey = {
        param($Drift)
        "$($Drift.resourceType)|$(ConvertTo-Json -InputObject $Drift.resourceInstanceIdentifier -Compress -Depth 5)|$($Drift.baselineResourceDisplayName)"
    }
    $formatResource = {
        param($Drift)
        # Microsoft365DSC-style keys that do not name an object: IsSingleInstance = 'Yes' marks a tenant-wide setting,
        # and Ensure or the connection parameters are never names.
        $ignoredKeys = @('IsSingleInstance', 'Ensure', 'Credential', 'ApplicationId', 'ApplicationSecret', 'TenantId', 'CertificateThumbprint', 'CertificatePath', 'ManagedIdentity', 'AccessTokens')
        $identifier = @{}
        $isSingleInstance = $false
        if ($Drift.resourceInstanceIdentifier) {
            foreach ($property in $Drift.resourceInstanceIdentifier.PSObject.Properties) {
                if ($property.Name -like '@odata*' -or $null -eq $property.Value -or "$($property.Value)" -eq '') { continue }
                if ($property.Name -eq 'IsSingleInstance') { $isSingleInstance = $true }
                if ($property.Name -in $ignoredKeys) { continue }
                $identifier[$property.Name] = "$($property.Value)"
            }
        }
        # The instance identifier names the object; the baseline display name is only the label of the baseline entry.
        $name = foreach ($key in 'DisplayName', 'Name', 'Identity', 'UserPrincipalName', 'Id') {
            if ($identifier.ContainsKey($key)) { $identifier[$key]; break }
        }
        if (-not $name -and $identifier.Count -gt 0) { $name = @($identifier.Values)[0] }
        # A tenant-wide setting has no instance name: it is named by its baseline entry (⚙️) instead of an object (📄).
        $icon = if (-not $name -and $isSingleInstance) { '⚙️' } else { '📄' }
        if (-not $name) {
            $name = if ($Drift.baselineResourceDisplayName) { $Drift.baselineResourceDisplayName } elseif ($isSingleInstance) { 'Tenant-wide setting' } else { 'Unnamed resource' }
        }
        $text = Get-MtSafeMarkdown $name

        $title = if ($Drift.baselineResourceDisplayName -and $Drift.baselineResourceDisplayName -ne $name) { "Baseline entry: $($Drift.baselineResourceDisplayName)" } elseif ($icon -eq '⚙️') { 'Tenant-wide setting' } else { $null }
        $titleText = if ($title) { " `"$($title -replace '["\\]', '' -replace '\r?\n', ' ' -replace '\|', '\|')`"" } else { '' }
        if (-not $entraPortal) { return "$icon $text" }

        $object = $objectLinkTemplates["$($Drift.resourceType)".ToLowerInvariant()]
        $parsedGuid = [guid]::Empty
        if ($object -and $identifier.ContainsKey($object.Key) -and [guid]::TryParse($identifier[$object.Key], [ref]$parsedGuid)) {
            return "$icon [$text]($($object.Template -f $identifier[$object.Key])$titleText)"
        }
        return "$icon [$text]($monitorUrl$titleText)"
    }
    # Drifted property values are JSON: show scalars as they are and objects as compact JSON in a code span.
    $formatValue = {
        param($Value)
        if ($null -eq $Value) { return '_empty_' }
        $text = if ($Value -is [string] -or $Value -is [ValueType]) { [string]$Value } else { ConvertTo-Json -InputObject $Value -Depth 5 -Compress }
        if ($text -eq '') { return '_empty_' }
        if ($text.Length -gt $MaximumValueLength) { $text = $text.Substring(0, $MaximumValueLength) + '…' }
        return '`' + ($text -replace '\|', '\|' -replace '`', "'" -replace '\r?\n', ' ') + '`'
    }
    # A list value, given as an array or as a JSON array string, as its items in compact JSON; IsList is $false otherwise.
    $readList = {
        param($Value)
        if ($null -eq $Value -or "$Value".Trim() -eq '') { return [pscustomobject]@{ IsList = $false; IsEmpty = $true; Items = @() } }
        $items = $null
        if ($Value -is [string]) {
            $text = $Value.Trim()
            if ($text.StartsWith('[') -and $text.EndsWith(']')) {
                try {
                    $parsed = ConvertFrom-Json -InputObject $text -ErrorAction Stop
                    $items = @($parsed | ForEach-Object { $_ })
                } catch { $items = $null }
            }
        } elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [System.Collections.IDictionary]) {
            $items = @($Value | ForEach-Object { $_ })
        }
        if ($null -eq $items) { return [pscustomobject]@{ IsList = $false; IsEmpty = $false; Items = @() } }
        $keys = @($items | Where-Object { $null -ne $_ } | ForEach-Object {
                if ($_ -is [string] -or $_ -is [ValueType]) { [string]$_ } else { ConvertTo-Json -InputObject $_ -Depth 5 -Compress }
            })
        [pscustomobject]@{ IsList = $true; IsEmpty = $keys.Count -eq 0; Items = $keys }
    }
    # For list values only the items that differ are shown: a long list cut at MaximumValueLength would hide them.
    # Returns $null when the values are not lists or differ only in order, so they are shown as they are.
    $formatListChange = {
        param($Current, $Desired)
        $currentList = & $readList $Current
        $desiredList = & $readList $Desired
        if (-not ($currentList.IsList -or $desiredList.IsList)) { return $null }
        if (-not ($currentList.IsList -or $currentList.IsEmpty) -or -not ($desiredList.IsList -or $desiredList.IsEmpty)) { return $null }
        $currentSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$currentList.Items, [System.StringComparer]::Ordinal)
        $desiredSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$desiredList.Items, [System.StringComparer]::Ordinal)
        $extra = @($currentList.Items | Where-Object { -not $desiredSet.Contains($_) } | Select-Object -Unique)
        $missing = @($desiredList.Items | Where-Object { -not $currentSet.Contains($_) } | Select-Object -Unique)
        if ($extra.Count -eq 0 -and $missing.Count -eq 0) { return $null }
        $maxItems = 5
        $formatSide = {
            param([string[]] $Changed, [int] $Total, [string] $Icon, [string] $Suffix)
            $countText = "$Total $(if ($Total -eq 1) { 'item' } else { 'items' })"
            if ($Changed.Count -eq 0) { return $(if ($Total -eq 0) { '_empty_' } else { $countText }) }
            $shownItems = @($Changed | Select-Object -First $maxItems | ForEach-Object { & $formatValue $_ }) -join ', '
            $moreText = if ($Changed.Count -gt $maxItems) { " +$($Changed.Count - $maxItems) more" } else { '' }
            "$Icon $shownItems$moreText $Suffix ($countText)"
        }
        [pscustomobject]@{
            Current = & $formatSide $extra $currentList.Items.Count '🔴' 'not in baseline'
            Desired = & $formatSide $missing $desiredList.Items.Count '🟢' 'missing'
        }
    }
    $formatFirstDetected = {
        param($Value)
        $detected = & $toUtc $Value
        if (-not $detected) { return 'Unknown' }
        $days = [int][math]::Floor(($nowUtc - $detected).TotalDays)
        $age = if ($days -lt 1) { 'today' } elseif ($days -eq 1) { '1 day' } else { "$days days" }
        "$($detected.ToString('yyyy-MM-dd', [cultureinfo]::InvariantCulture)) ($age)"
    }
    # One row per drifted property; the resource and its first detection are only on its first row, so the rows of
    # one resource read as a group.
    $formatDriftRows = {
        param($Drift)
        $resource = & $formatResource $Drift
        $detected = & $formatFirstDetected $Drift.firstReportedDateTime
        $properties = @($Drift.driftedProperties | Where-Object { $null -ne $_ })
        if ($properties.Count -eq 0) { return "| $resource | _Not reported_ | | | $detected |`n" }
        $rows = ''
        $first = $true
        foreach ($property in @($properties | Select-Object -First $MaxPropertiesPerResource)) {
            $cells = if ($first) { "| $resource |" } else { '| |' }
            $change = & $formatListChange $property.currentValue $property.desiredValue
            $currentText = if ($change) { $change.Current } else { & $formatValue $property.currentValue }
            $desiredText = if ($change) { $change.Desired } else { & $formatValue $property.desiredValue }
            $rows += "$cells $(Get-MtSafeMarkdown $property.propertyName) | $currentText | $desiredText | $(if ($first) { $detected }) |`n"
            $first = $false
        }
        if ($properties.Count -gt $MaxPropertiesPerResource) {
            $rows += "| | _+$($properties.Count - $MaxPropertiesPerResource) more properties_ | | | |`n"
        }
        $rows
    }

    # Summary, then the monitor's status and last run.
    $testResult = $drifts.Count -eq 0
    $runsIncomplete = $runNotSuccessful -or $isOverdue -or $awaitingFirstRun -or [bool]$runsError
    if (-not $testResult) {
        $resourceCount = @($drifts | ForEach-Object { & $resourceKey $_ } | Select-Object -Unique).Count
        $testResultMarkdown = "$monitorLink reports **$($drifts.Count)** active configuration $(if ($drifts.Count -eq 1) { 'drift' } else { 'drifts' }) on $resourceCount $(if ($resourceCount -eq 1) { 'resource' } else { 'resources' }). Restore each setting to the desired value, or update the baseline if the change was intended."
    } elseif (-not $isActive -or $runsIncomplete) {
        $testResultMarkdown = "$monitorLink reports no active configuration drift, but this can be incomplete."
    } else {
        $testResultMarkdown = "Well done. $monitorLink reports no active configuration drift."
    }
    $notes = @(
        if (-not $isActive) { '⏸️ The monitor is inactive and no longer detects drift. Check its permissions and turn it on again, or delete it.' }
        if ($runNotSuccessful) { "⚠️ The last run did not report success (status: $(if ($lastRun.runStatus) { Get-MtSafeMarkdown "$($lastRun.runStatus)" } else { 'none' })), so drift may be missing or out of date. Check the $(if ($entraPortal) { "[Monitor results]($monitorResultsUrl)" } else { '**Monitor results**' }) of the monitor." }
        if ($isOverdue) { "⏰ The monitor has not run as scheduled (every $frequency h)." }
        if ($awaitingFirstRun) { "⏳ The monitor has not run yet. Its first run is expected within $overdueAfterHours h of its creation; until then, no drift only means that the settings were not checked." }
        if ($runsError) { "❔ The monitor runs could not be read, so the last run is unknown ($(& $escape $runsError))." }
    )
    # The warnings follow the monitor's properties, directly under the result sentence.

    # The monitor at a glance: one line per property, each with its own icon.
    $resourceTotal = @($drifts | ForEach-Object { & $resourceKey $_ } | Select-Object -Unique).Count
    $modeText = switch ($monitor.mode) {
        'monitorOnly' { 'Monitor only: reports drift and does not change settings' }
        $null { $null }
        default { "$($monitor.mode)" }
    }
    # How long the tenant has been out of line with the baseline: the first detection of the oldest active drift.
    $oldestDrift = @($drifts | ForEach-Object { & $toUtc $_.firstReportedDateTime } | Where-Object { $_ } | Sort-Object | Select-Object -First 1)
    $oldestText = if ($oldestDrift.Count -gt 0) { " · oldest since $(& $formatFirstDetected $oldestDrift[0])" } else { '' }
    $created = & $formatChangeDate $monitor.createdDateTime
    $modified = & $formatChangeDate $monitor.lastModifiedDateTime
    $card = @(
        if ($isActive) { '🟢 **Status:** Active' } else { "⏸️ **Status:** Inactive$(if ($monitor.inactivationReason) { " · $(Get-MtSafeMarkdown $monitor.inactivationReason)" })" }
        "$runIcon **Last run:** $runText$(if ($monitorResultsLink) { " · $monitorResultsLink" })"
        "⏱️ **Schedule:** Every $frequency h"
        if ($drifts.Count -gt 0) { "🔀 **Active drifts:** $($drifts.Count) on $resourceTotal $(if ($resourceTotal -eq 1) { 'resource' } else { 'resources' })$oldestText" } else { '✨ **Active drifts:** None' }
        if ($modeText) { "🛠️ **Mode:** $modeText" }
        if ($monitor.description) { "📝 **Description:** $(Get-MtSafeMarkdown $monitor.description)" }
        if ($created) { "🗓️ **Created:** $created$(& $formatIdentity $monitor.createdBy)" }
        if ($modified -and "$($monitor.lastModifiedDateTime)" -ne "$($monitor.createdDateTime)") { "✏️ **Last changed:** $modified$(& $formatIdentity $monitor.lastModifiedBy)" }
    )
    $testResultMarkdown += "`n`n" + (($card | ForEach-Object { "- $_" }) -join "`n") + "`n"
    if ($notes.Count -gt 0) { $testResultMarkdown += "`n" + ($notes -join "`n`n") + "`n" }

    # One table per resource type, oldest drift first.
    if (-not $testResult) {
        $testResultMarkdown += "`n### 🔀 Configuration drift`n"
        $sorted = @($drifts | Sort-Object -Property resourceType, @{ Expression = { & $toUtc $_.firstReportedDateTime } })
        $shown = @($sorted | Select-Object -First $MaxDriftsPerMonitor)
        foreach ($typeGroup in @($shown | Group-Object -Property resourceType)) {
            $typeTotal = @($sorted | Where-Object { $_.resourceType -eq $typeGroup.Name }).Count
            $testResultMarkdown += "`n#### $(& $formatResourceType $typeGroup.Name) · $typeTotal $(if ($typeTotal -eq 1) { 'resource' } else { 'resources' })`n`n"
            $testResultMarkdown += "| Resource | Property | Current value | Desired value | First detected |`n| --- | --- | --- | --- | --- |`n"
            foreach ($drift in $typeGroup.Group) {
                $testResultMarkdown += & $formatDriftRows $drift
            }
        }
        $hidden = $sorted.Count - $shown.Count
        if ($hidden -gt 0) {
            $testResultMarkdown += "`n… and $hidden more $(if ($hidden -eq 1) { 'drift' } else { 'drifts' }). Open $monitorLink to see all of them.`n"
        }
    }

    # No drift is only reassuring when the monitor is active and actually ran.
    if ($testResult -and (-not $isActive -or $runsIncomplete)) {
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        return $testResult
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
