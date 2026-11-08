function Get-MtSecureScoreControlInstance {
    <#
    .SYNOPSIS
    Returns one MT.1264 instance per Microsoft Secure Score control the tenant is scored on.

    .DESCRIPTION
    Instance source of the MT.1264 family. The instances come from controlScores in the latest Secure
    Score snapshot, not from the full secureScoreControlProfiles catalog: the catalog lists every control
    Microsoft has (including ones for products the tenant does not use), while the snapshot lists only the
    controls the tenant is actually scored on. Each control is joined to its profile for the title, the
    maximum points and the remediation. The suffix is the control name (MT.1264.<controlName>), made a
    valid instance ID by ConvertTo-MtSecureScoreInstanceId when it is not one, and the severity comes from the
    control's maximum points.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    try {
        # Only the latest daily snapshot. Without -DisablePaging the helper would follow nextLink through
        # up to 90 days of history.
        $snapshotResponse = Invoke-MtGraphRequest -RelativeUri 'security/secureScores' -QueryParameters @{ '$top' = 1 } -DisablePaging
        $snapshot = @($snapshotResponse.value) | Select-Object -First 1
        $profiles = @(Invoke-MtGraphRequest -RelativeUri 'security/secureScoreControlProfiles')
    } catch {
        if ($_.Exception.Message -match '(?i)403|forbidden|authorization') {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
            return
        }
        throw
    }

    # No snapshot yet (for example a brand new tenant): no instances, so the engine skips the family.
    if ($null -eq $snapshot) { return }

    $profileLookup = @{}
    foreach ($controlProfile in $profiles) { $profileLookup[[string]$controlProfile.id] = $controlProfile }

    # Entra recommendations MT.1024 already reports. Some Secure Score controls are the same recommendation
    # under the same name (AdminMFAV2 and adminMFAV2), so those results say so. Matched by name, not by the
    # control's service: not every AzureAD control is an Entra recommendation. Same request as MT.1024, so
    # it comes from the Graph cache when MT.1024 has run. If it fails, the results just carry no note.
    $entraRecommendationTypes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $recommendations = Invoke-MtGraphRequest -ApiVersion beta -RelativeUri 'directory/recommendations?$expand=impactedResources' -OutputType Hashtable
        foreach ($recommendation in @($recommendations.value)) {
            if ($recommendation -and $recommendation.recommendationType) { [void]$entraRecommendationTypes.Add([string]$recommendation.recommendationType) }
        }
    } catch {
        Write-Verbose "MT.1264: could not read Entra recommendations, so no result notes the overlap with MT.1024. $($_.Exception.Message)"
    }

    # Instance IDs must match ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ and be unique, or the engine errors the whole
    # family. Control names are Microsoft's, so one with a space or another character would break every result.
    $usedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($controlScore in @($snapshot.controlScores)) {
        $controlName = [string]$controlScore.controlName
        $controlProfile = $profileLookup[$controlName]
        if ($controlProfile.deprecated) { continue }
        $instanceId = ConvertTo-MtSecureScoreInstanceId -ControlName $controlName -UsedId $usedIds
        if (-not $instanceId) {
            Write-Verbose "MT.1264: skipped a Secure Score control with no usable name ('$controlName')."
            continue
        }
        # A scored control with no profile has no maximum to compare against. Keep it as an instance so
        # the test reports it as an error instead of dropping it from the results.
        if ($null -eq $controlProfile) {
            [pscustomobject]@{
                Id       = $instanceId
                Title    = "$controlName."
                Severity = 'Medium'
                Tag      = @(@($controlScore.controlCategory) | Where-Object { $_ })
                Data     = [pscustomobject]@{ ControlScore = $controlScore; Profile = $null; InMt1024 = $false }
            }
            continue
        }

        $placement = Get-MtSecureScoreControlProduct -Service ([string]$controlProfile.service)
        [pscustomobject]@{
            Id       = $instanceId
            Title    = "$($controlProfile.title)."
            Severity = Get-MtSecureScoreControlSeverity -MaxScore ([double]$controlProfile.maxScore)
            # Each action sits under the product it is about (Entra, Exchange, Teams...), not the family's Defender.
            Product  = $placement.Product
            Feature  = $placement.Feature
            # The service (MDO, AzureAD, EXO...) and category (Apps, Identity...) as tags, so -Tag can pick
            # out one service's actions.
            Tag      = @(@($controlProfile.service, $controlProfile.controlCategory) | Where-Object { $_ } | Select-Object -Unique)
            Data     = [pscustomobject]@{
                ControlScore = $controlScore
                Profile      = $controlProfile
                InMt1024     = $entraRecommendationTypes.Contains($controlName)
            }
        }
    }
}

function ConvertTo-MtSecureScoreInstanceId {
    <#
    .SYNOPSIS
    Turns a Secure Score control name into an instance ID the engine accepts, unique within the family.

    .DESCRIPTION
    Most control names (mdo_safelinks, AdminMFAV2) are valid IDs and are returned unchanged. A character outside
    A-Z, a-z, 0-9, '.', '_' and '-' becomes '-', leading characters that are not a letter or digit are dropped and
    the result is cut to 128 characters. A name that collides with one already used gets -2, -3... Returns
    nothing for a name with no letter or digit. Adds the returned ID to UsedId.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $ControlName,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.HashSet[string]] $UsedId
    )

    $id = ($ControlName -replace '[^A-Za-z0-9._-]', '-') -replace '^[^A-Za-z0-9]+', ''
    if (-not $id) { return }
    if ($id.Length -gt 128) { $id = $id.Substring(0, 128) }
    $candidate = $id
    $n = 1
    while (-not $UsedId.Add($candidate)) {
        $n++
        $suffix = "-$n"
        $candidate = $id.Substring(0, [Math]::Min($id.Length, 128 - $suffix.Length)) + $suffix
    }
    $candidate
}

function Get-MtSecureScoreControlProduct {
    <#
    .SYNOPSIS
    Maps a Secure Score control's service to the Maester product (and feature, where one fits) it is about.

    .DESCRIPTION
    Secure Score names the service that owns each improvement action (AzureAD, EXO, MS Teams...). The engine
    places a family instance under the Product and Feature it sets, checked against the taxonomy. A service
    with no clear product returns nothing, so the instance keeps the family's Defender product and feature.
    Defender for Cloud Apps connectors (MDA_*) stay under Defender.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()] [AllowEmptyString()] [string] $Service
    )

    $map = @{
        'AzureAD'     = @{ Product = 'entra' }
        'EXO'         = @{ Product = 'exchange' }
        'MS Teams'    = @{ Product = 'teams' }
        'SPO'         = @{ Product = 'sharepoint' }
        'MIP'         = @{ Product = 'purview' }
        'FORMS'       = @{ Product = 'microsoft-365' }
        'SWAY'        = @{ Product = 'microsoft-365' }
        'Admincenter' = @{ Product = 'microsoft-365' }
        'Azure ATP'   = @{ Product = 'defender'; Feature = 'defender-for-identity' }
    }
    if ($Service -and $map.ContainsKey($Service)) { return $map[$Service] }
    return @{ Product = $null; Feature = $null }
}

function Get-MtSecureScoreControlSeverity {
    <#
    .SYNOPSIS
    Maps a Secure Score control's maximum points to a Maester severity.

    .DESCRIPTION
    8 or more points is High, 4 to 7 is Medium, below 4 is Low. Based on points only: the control rank is
    not used because some controls return rank 0, which does not mean top-ranked.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [double] $MaxScore
    )

    if ($MaxScore -ge 8) { return 'High' }
    if ($MaxScore -ge 4) { return 'Medium' }
    return 'Low'
}

function ConvertFrom-MtSecureScoreHtml {
    <#
    .SYNOPSIS
    Turns the HTML in Secure Score descriptions into plain markdown.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) { return '' }
    $text = $Html -replace "<a[^>]+href=[`"']([^`"']+)[`"'][^>]*>(.*?)</a>", '[$2]($1)'
    $text = $text -replace '(?i)<li[^>]*>', "`n- " -replace '(?i)<br\s*/?>', "`n" -replace '(?i)</p>|</h4>', "`n`n"
    $text = $text -replace '<[^>]+>', ''
    $text = [System.Net.WebUtility]::HtmlDecode($text)
    # Collapse runs of blank lines and trim each line.
    $lines = $text -split "`r?`n" | ForEach-Object { $_.Trim() }
    return (($lines -join "`n") -replace "`n{3,}", "`n`n").Trim()
}

function Test-MtSecureScoreControl {
    <#
    .SYNOPSIS
    Checks that a Microsoft Secure Score control has its full points.

    .DESCRIPTION
    Runs once per Microsoft Secure Score control the tenant is scored on. Passes when the control's score
    equals its maximum points and fails when it is lower, showing the points attained. Controls an admin has
    marked in the Defender portal as risk accepted (Ignored), resolved through third party (ThirdParty),
    resolved through alternate mitigation (AlternateMitigation) or reviewed (Reviewed) are skipped with the
    reason and who set it, so decisions already made in the portal are respected. Planned controls are
    still checked, since the work is not done yet.

    .LINK
    https://maester.dev/docs/tests/MT.1264
    #>
    [MaesterTest(
        Id = 'MT.1264',
        Title = 'Microsoft Secure Score improvement actions should be completed.',
        Product = 'defender',
        Feature = 'exposure-management',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Cloud = ('Commercial', 'GCC', 'GCCHigh', 'DoD'),
        Service = 'Graph',
        Permission = 'Graph:Scope:SecurityEvents.Read.All',
        Lifecycle = 'Preview',
        InstanceSource = 'Get-MtSecureScoreControlInstance',
        Author = 'Dfrank77'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The Secure Score control to check, supplied by the engine.
        $Instance
    )

    $controlScore = $Instance.Data.ControlScore
    $controlProfile = $Instance.Data.Profile
    if ($null -eq $controlProfile) {
        throw "Secure Score control '$($controlScore.controlName)' is in the tenant's score but has no control profile, so its maximum points could not be read."
    }
    $score = [double]$controlScore.score
    $maxScore = [double]$controlProfile.maxScore
    $severity = $Instance.Severity

    #region Build test description markdown
    $descriptionMd = ConvertFrom-MtSecureScoreHtml -Html ([string]$controlScore.description)
    $remediation = ConvertFrom-MtSecureScoreHtml -Html ([string]$controlProfile.remediation)
    if ($remediation) { $descriptionMd += "`n`n#### Remediation action:`n`n$remediation" }
    $impact = ConvertFrom-MtSecureScoreHtml -Html ([string]$controlProfile.remediationImpact)
    if ($impact) { $descriptionMd += "`n`n**User impact:** $impact" }
    if ($Instance.Data.InMt1024) {
        $descriptionMd += "`n`nThis improvement action is also an Entra recommendation, reported by MT.1024 (Entra recommendations)."
    }
    $actionLinkMd = ''
    if ($controlProfile.actionUrl) {
        $actionLinkMd = "`n`n➡️ [Open this improvement action]($($controlProfile.actionUrl))"
        $descriptionMd += $actionLinkMd
    }
    #endregion Build test description markdown

    # Decisions made in the Defender portal. The latest dated update is the current state; 'Default'
    # means nobody has set one. Portal status -> state: Risk accepted -> Ignored, Resolved through third
    # party -> ThirdParty, Resolved through alternate mitigation -> AlternateMitigation, Planned -> Planned.
    # Planned and AlternateMitigation are returned by the API but not listed in the Graph docs. Planned
    # is not skipped: the work is not done yet. Reviewed is a documented state and is skipped as well.
    $stateUpdates = @($controlProfile.controlStateUpdates | Where-Object { $_ })
    $latestState = $stateUpdates | Sort-Object -Property @{ Expression = { $_.updatedDateTime -as [datetime] } } -Descending | Select-Object -First 1
    $stateNames = @{
        Ignored             = 'risk accepted'
        ThirdParty          = 'resolved through third party'
        AlternateMitigation = 'resolved through alternate mitigation'
        Reviewed            = 'reviewed'
    }
    if ($latestState -and $stateNames.ContainsKey([string]$latestState.state)) {
        $reason = "This improvement action is marked as **$($stateNames[[string]$latestState.state])** ($($latestState.state)) in the Microsoft Defender portal"
        if ($latestState.updatedBy) { $reason += " by $($latestState.updatedBy)" }
        $reason += '.'
        if ($latestState.comment) { $reason += "`n`nComment: $(Get-MtSafeMarkdown ([string]$latestState.comment))" }
        $reason += "`n`nIf it applies to this tenant, change its status back to **To address** to have Maester check it again.$actionLinkMd"
        Add-MtTestResultDetail -Description $descriptionMd -Severity $severity -SkippedBecause Custom -SkippedCustomReason $reason
        return $null
    }

    $passed = $score -ge $maxScore
    $resultMd = "**$score of $maxScore points** for this improvement action."
    $status = ConvertFrom-MtSecureScoreHtml -Html ([string]$controlScore.implementationStatus)
    if ($status) { $resultMd += "`n`n$status" }
    if (-not $passed) { $resultMd += $actionLinkMd }

    Add-MtTestResultDetail -Description $descriptionMd -Severity $severity -Result $resultMd
    return $passed
}
