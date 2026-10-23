function Write-Telemetry {
    <#
    .SYNOPSIS
    Sends one anonymous telemetry event to packs.maester.cloud.

    .DESCRIPTION
    InvokeMaester is sent at the end of a run: a random installation ID (Get-MtInstallationId), a SHA-256 hash of
    the tenant ID, the Maester version, the platform, the CI system if any, the number of tests that ran, and each
    public or built-in Maester Pack that ran, with its source, version and test count. A pack installed from a
    private repository or a local folder is never sent.

    PackInstall is sent by Install-MtPack for a pack from a public GitHub repository: its source, commit and the
    installation ID. It also tells the pack index that the pack exists.

    Nothing is sent when Invoke-Maester -DisableTelemetry is used or MAESTER_DISABLE_TELEMETRY is set to anything
    but 0 or false. MAESTER_TELEMETRY_URL sends events to another Worker, for testing. A failure is written to the
    verbose stream and never stops the command.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('InvokeMaester', 'PackInstall')]
        [string] $EventName,

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

    if ($EventName -eq 'PackInstall') {
        if (-not $Pack -or -not $Pack.Commit -or -not ($Pack.PSObject.Properties['Public'] -and $Pack.Public) -or $Pack.Source -eq 'builtin') { return }
        $uri = "$baseUrl/api/v1/events"
        $body = [ordered]@{
            Type           = 'install'
            Source         = [string]$Pack.Source
            Commit         = [string]$Pack.Commit
            Id             = [string]$Pack.Id
            MaesterVersion = [string](Get-MtModuleVersion)
            InstallationId = $installationId
            CI             = [bool]$ci
        }
    } else {
        $tenantHash = ''
        $tenantId = try { [string](Get-MgContext).TenantId } catch { $null }
        if ($tenantId) {
            $bytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes("maester:$($tenantId.ToLowerInvariant())"))
            $tenantHash = [System.Convert]::ToHexString($bytes).ToLowerInvariant()
        }
        $os = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'macOS' } elseif ($IsLinux) { 'Linux' } else { 'Other' }

        # A row ran when it has a result other than NotRun or Skipped; pack rows carry the pack as Package.
        $ran = @($MaesterResults.Tests | Where-Object { $_ -and $_.Result -notin 'NotRun', 'Skipped' })
        $packs = foreach ($group in ($ran | Where-Object { $_.PSObject.Properties['Package'] -and $_.Package -and $_.Package.Id } | Group-Object { $_.Package.Id })) {
            $set = $PackSet | Where-Object { $_.Id -eq $group.Name } | Select-Object -First 1
            if (-not $set) { continue }
            $source = if ($set.BuiltIn -and $set.Root) { "maester365/maester/packs/$(Split-Path -Path $set.Root -Leaf)" }
            elseif ($set.Entry -and $set.Entry.PSObject.Properties['Public'] -and $set.Entry.Public -and $set.Entry.Source -ne 'builtin') { [string]$set.Entry.Source }
            else { $null }
            if (-not $source) { continue }
            [ordered]@{ Source = $source; Version = [string]$set.Version; Tests = $group.Count }
        }
        $uri = "$baseUrl/api/v1/telemetry"
        $body = [ordered]@{
            Type           = 'run'
            InstallationId = $installationId
            Tenant         = $tenantHash
            MaesterVersion = [string](Get-MtModuleVersion)
            OS             = $os
            CI             = $ci
            Tests          = $ran.Count
            Packs          = @($packs | Select-Object -First 50)
        }
    }

    Write-Verbose "Sending telemetry event: $EventName"
    try {
        $json = ConvertTo-Json -InputObject $body -Depth 4 -Compress
        Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json' -Body $json -TimeoutSec 3 -ErrorAction Stop | Out-Null
    } catch {
        Write-Verbose "Telemetry was not sent: $($_.Exception.Message)"
    }
}
