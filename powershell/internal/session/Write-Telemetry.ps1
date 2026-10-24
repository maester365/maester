function Write-Telemetry {
    <#
    .SYNOPSIS
    Sends one anonymous telemetry event to packs.maester.cloud.

    .DESCRIPTION
    Every event carries a random installation ID (Get-MtInstallationId), the Maester and PowerShell versions, the
    platform and the CI system if any. The service looks up the country and region of the request and does not
    store the IP address.

    InvokeMaesterStart is sent when Invoke-Maester starts: the run's random ID and a SHA-256 hash of the tenant ID.
    It also sends the event PostHog has always received, until PostHog is retired.

    InvokeMaester is sent when the run ends, whether it completed or not: the run ID, when it started and how long
    it took, its outcome (Completed, or Incomplete with the stage it reached and the type of the last error), the
    result counts, the public Maester Packs installed and each public or built-in pack that ran, with its source,
    version and test count. A run that starts and never ends shows a crash. A pack installed from a private
    repository or a local folder is never sent.

    PackInstall is sent by Install-MtPack for a pack from a public GitHub repository: its source, commit and the
    installation ID. It also tells the pack index that the pack exists.

    Nothing is sent when Invoke-Maester -DisableTelemetry is used or MAESTER_DISABLE_TELEMETRY is set to anything
    but 0 or false. MAESTER_TELEMETRY_URL sends events to another Worker, for testing. A failure is written to the
    verbose stream and never stops the command. Events are sent in the background, so they never slow a run down.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('InvokeMaesterStart', 'InvokeMaester', 'PackInstall')]
        [string] $EventName,

        # InvokeMaesterStart and InvokeMaester: the run, with RunId, StartedAt (UTC) and Stage.
        [Parameter()]
        [object] $Run,

        # InvokeMaester: Completed, or Incomplete when the run stopped early, failed or was cancelled.
        [Parameter()]
        [ValidateSet('Completed', 'Incomplete')]
        [string] $Outcome = 'Completed',

        # InvokeMaester: the .NET type of the error that stopped the run, never its message.
        [Parameter()]
        [string] $ErrorType,

        # InvokeMaester: the run's results, from ConvertTo-MtMaesterResult.
        [Parameter()]
        [object] $MaesterResults,

        # InvokeMaester: the packs of the run, from Initialize-MtPackSet.
        [Parameter()]
        [object[]] $PackSet = @(),

        # PackInstall: the lock entry Invoke-MtPackInstall wrote.
        [Parameter()]
        [object] $Pack
    )

    if ($env:MAESTER_DISABLE_TELEMETRY -and $env:MAESTER_DISABLE_TELEMETRY -notin '0', 'false') { return }
    $installationId = Get-MtInstallationId
    if (-not $installationId) { return }
    $ci = if ($env:GITHUB_ACTIONS -eq 'true') { 'GitHubActions' }
    elseif ($env:TF_BUILD -eq 'True') { 'AzureDevOps' }
    elseif ($env:CI -and $env:CI -ne 'false') { 'Other' }
    else { $null }
    $baseUrl = if ($env:MAESTER_TELEMETRY_URL) { $env:MAESTER_TELEMETRY_URL.TrimEnd('/') } else { 'https://packs.maester.cloud' }
    # Starts the request in the background and returns at once (Send-MtTelemetryRequest); the command that sent it
    # calls Wait-MtTelemetry as it returns.
    $send = {
        param($uri, $body)
        try {
            $json = ConvertTo-Json -InputObject $body -Depth 4 -Compress
            Send-MtTelemetryRequest -Uri $uri -Body $json
        } catch {
            Write-Verbose "Telemetry was not sent: $($_.Exception.Message)"
        }
    }
    Write-Verbose "Sending telemetry event: $EventName"

    if ($EventName -eq 'PackInstall') {
        if (-not $Pack -or -not $Pack.Commit -or -not ($Pack.PSObject.Properties['Public'] -and $Pack.Public) -or $Pack.Source -eq 'builtin') { return }
        & $send "$baseUrl/api/v1/events" ([ordered]@{
                Type           = 'install'
                Source         = [string]$Pack.Source
                Commit         = [string]$Pack.Commit
                Id             = [string]$Pack.Id
                MaesterVersion = [string](Get-MtModuleVersion)
                InstallationId = $installationId
                CI             = [bool]$ci
            })
        return
    }

    $tenantId = try { [string](Get-MgContext).TenantId } catch { $null }
    $tenantHash = ''
    if ($tenantId) {
        $bytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes("maester:$($tenantId.ToLowerInvariant())"))
        $tenantHash = [System.Convert]::ToHexString($bytes).ToLowerInvariant()
    }
    $os = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } elseif ($IsLinux) { 'Linux' } else { 'Other' }
    $osVersion = [string][System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    if ($osVersion.Length -gt 100) { $osVersion = $osVersion.Substring(0, 100) }
    $body = [ordered]@{
        Type           = $(if ($EventName -eq 'InvokeMaesterStart') { 'start' } else { 'run' })
        RunId          = $(if ($Run) { [string]$Run.RunId } else { '' })
        InstallationId = $installationId
        Tenant         = $tenantHash
        MaesterVersion = [string](Get-MtModuleVersion)
        PowerShell     = [string]$PSVersionTable.PSVersion
        OS             = $os
        OSVersion      = $osVersion
        Architecture   = [string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
        CI             = $ci
    }

    if ($EventName -eq 'InvokeMaesterStart') {
        & $send "$baseUrl/api/v1/telemetry" $body
        # The PostHog event Maester has always sent; it goes when the run's events are trusted on their own.
        & $send 'https://us.i.posthog.com/capture/' ([ordered]@{
                api_key     = 'phc_VxA235FsdurMGycf9DHjlUeZeIhLuC7r11Ptum0WjRK'
                distinct_id = $(if ($tenantId) { $tenantId } else { 'unknown' })
                event       = 'InvokeMaester'
            })
        return
    }

    # A row ran when it has a result other than NotRun or Skipped; pack rows carry the pack as Package.
    $tests = @($MaesterResults.Tests | Where-Object { $_ })
    $ran = @($tests | Where-Object { $_.Result -notin 'NotRun', 'Skipped' })
    $publicSource = {
        param($set)
        if ($set.BuiltIn -and $set.Root) { "maester365/maester/packs/$(Split-Path -Path $set.Root -Leaf)" }
        elseif ($set.Entry -and $set.Entry.PSObject.Properties['Public'] -and $set.Entry.Public -and $set.Entry.Source -ne 'builtin') { [string]$set.Entry.Source }
    }
    $packs = foreach ($group in ($ran | Where-Object { $_.PSObject.Properties['Package'] -and $_.Package -and $_.Package.Id } | Group-Object { $_.Package.Id })) {
        $set = $PackSet | Where-Object { $_.Id -eq $group.Name } | Select-Object -First 1
        $source = if ($set) { & $publicSource $set }
        if (-not $source) { continue }
        [ordered]@{ Source = $source; Version = [string]$set.Version; Tests = $group.Count }
    }
    # Installed: the public packs in the lock file, whether or not this run selected them.
    $installed = foreach ($set in ($PackSet | Where-Object { $_ -and -not $_.BuiltIn -and $_.Entry })) {
        $source = & $publicSource $set
        if ($source) { [ordered]@{ Source = $source; Version = [string]$set.Version } }
    }
    $durationMs = 0
    if ($Run -and $Run.StartedAt) { $durationMs = [long][Math]::Max(0, ([datetime]::UtcNow - $Run.StartedAt).TotalMilliseconds) }
    $count = { param($result) @($tests | Where-Object { $_.Result -eq $result }).Count }

    $body.StartedAt = $(if ($Run -and $Run.StartedAt) { $Run.StartedAt.ToString('o') } else { '' })
    $body.DurationMs = $durationMs
    $body.Outcome = $Outcome
    $body.Stage = $(if ($Run -and $Outcome -ne 'Completed') { [string]$Run.Stage } else { '' })
    $body.ErrorType = $(if ($Outcome -ne 'Completed' -and $ErrorType) { $ErrorType.Substring(0, [Math]::Min(100, $ErrorType.Length)) } else { '' })
    $body.Tests = $ran.Count
    $body.Results = [ordered]@{
        Passed  = & $count 'Passed'
        Failed  = & $count 'Failed'
        Error   = & $count 'Error'
        Skipped = & $count 'Skipped'
        NotRun  = & $count 'NotRun'
    }
    $body.Installed = @($installed | Select-Object -First 50)
    $body.Packs = @($packs | Select-Object -First 50)
    & $send "$baseUrl/api/v1/telemetry" $body
}
