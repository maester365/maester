<#
.SYNOPSIS
    Binary hard-fail preflight gate for the Azure AD E2E lab.

.DESCRIPTION
    Validates every mandatory prerequisite before any E2E matrix row runs.
    Checks are exhaustive and fail closed:

    1. VM power state (all lab VMs)
    2. Runner DNS resolution for every mandatory DC FQDN
    3. Resolved RootDSE identity for each DC via the protocol path
    4. Banned-module absence on both runners
    5. LDAPS certificate trust and hostname validity (TLS on 636)
    6. StartTLS negotiation success on 389 (full TLS handshake, not just reachability)
    7. Runner implicit-authentication readiness for root-forest rows
    8. Forest-trust assertions (intra-forest trust present, separate-forest trust absent)

    The script emits a machine-readable JSON artifact and exits non-zero when
    any mandatory check fails, with clear attribution.

.PARAMETER ResourceGroupName
    Azure resource group containing the lab VMs.

.PARAMETER TagName
    Tag key used to discover the lab resources.

.PARAMETER TagValue
    Tag value used to discover the lab resources.

.PARAMETER EvidencePath
    Directory where the JSON artifact is written. Defaults to a sibling
    'evidence' folder under this script's directory.

.EXAMPLE
    ./Test-LabPrerequisites.ps1 -TagName maester-lab-id -TagValue misoule-lab-20260818190000

    Runs the full preflight gate and writes the JSON artifact.
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Runner script provides status output and emits machine-readable JSON artifact.'
)]
param(
    [Parameter()]
    [string]$ResourceGroupName = 'RG_5100_MiSoule_2',

    [Parameter(Mandatory)]
    [string]$TagName,

    [Parameter(Mandatory)]
    [string]$TagValue,

    [Parameter()]
    [string]$EvidencePath = (Join-Path $PSScriptRoot 'evidence')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Invoke-LabAzCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$ExpectJson
    )

    $azCommand = Get-Command -Name 'az' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $azCommand) {
        throw 'Azure CLI (az) is required but was not found in PATH.'
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $azCommand.Source
    $psi.Arguments = ($Arguments | ForEach-Object {
        if ($_ -match '\s') { '"{0}"' -f $_ } else { $_ }
    }) -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::Start($psi)
    $output = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    if ($exitCode -ne 0) {
        throw "Azure CLI command failed ($exitCode): az $($Arguments -join ' ')`n$output"
    }

    if ($ExpectJson.IsPresent -and $output) {
        return $output | ConvertFrom-Json
    }

    return $output
}

function Invoke-LabVmRunCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$VmName,

        [Parameter(Mandatory)]
        [string]$CommandId,

        [Parameter(Mandatory)]
        [string]$ScriptContent
    )

    $temporaryFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $temporaryFile -Value $ScriptContent -Encoding utf8
        return Invoke-LabAzCli -Arguments @(
            'vm', 'run-command', 'invoke',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName,
            '--command-id', $CommandId,
            '--scripts', ('@{0}' -f $temporaryFile),
            '--query', 'value[0].message',
            '--output', 'tsv'
        )
    } finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

function Add-PreflightCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[object]]$List,

        [Parameter(Mandatory)]
        [string]$CheckId,

        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter()]
        [string]$Runner = $null,

        [Parameter()]
        [string]$RequestedTarget = $null,

        [Parameter()]
        [string]$ResolvedTarget = $null,

        [Parameter()]
        [object]$Expected = $null,

        [Parameter()]
        [object]$Actual = $null,

        [Parameter()]
        [bool]$Success = $false,

        [Parameter()]
        [bool]$Mandatory = $true,

        [Parameter()]
        [hashtable]$Details = @{}
    )

    $List.Add([PSCustomObject]@{
        CheckId         = $CheckId
        Category        = $Category
        Target          = $Target
        Runner          = $Runner
        RequestedTarget = $RequestedTarget
        ResolvedTarget  = $ResolvedTarget
        Expected        = $Expected
        Actual          = $Actual
        Success         = $Success
        Mandatory       = $Mandatory
        Details         = $Details
        Timestamp       = [datetime]::UtcNow.ToString('o')
    })
}

# ---------------------------------------------------------------------------
# 0) Discovery
# ---------------------------------------------------------------------------
$vmNames = @('MiSouleDC02', 'MiSouleDC03', 'MiSouleDC04', 'MiSouleRunnerWin', 'MiSouleRunnerLinux')
$results = [System.Collections.Generic.List[object]]::new()

$taggedResources = Invoke-LabAzCli -Arguments @(
    'resource', 'list',
    '--tag', ('{0}={1}' -f $TagName, $TagValue),
    '--query', "[?resourceGroup=='$ResourceGroupName'].name",
    '--output', 'tsv'
)

if (-not @($taggedResources | Where-Object { $_ }).Count) {
    throw "No resources tagged with $TagName=$TagValue were found in '$ResourceGroupName'."
}

# ---------------------------------------------------------------------------
# 1) Power state
# ---------------------------------------------------------------------------
foreach ($vmName in $vmNames) {
    $powerState = Invoke-LabAzCli -Arguments @(
        'vm', 'get-instance-view',
        '--resource-group', $ResourceGroupName,
        '--name', $vmName,
        '--query', "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus | [0]",
        '--output', 'tsv'
    )

    Add-PreflightCheck -List $results `
        -CheckId "PowerState.$vmName" `
        -Category 'PowerState' `
        -Target $vmName `
        -Expected 'VM running' `
        -Actual $powerState `
        -Success ($powerState -eq 'VM running') `
        -Mandatory $true
}

# ---------------------------------------------------------------------------
# 2) Windows runner comprehensive gate
# ---------------------------------------------------------------------------
$windowsRunnerScript = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$output = [ordered]@{
    DnsResults        = [System.Collections.Generic.List[object]]::new()
    BannedModuleCount = 0
    BannedModules     = [System.Collections.Generic.List[string]]::new()
    IsDomainJoined    = $false
    JoinedDomain      = $null
    LdapsResults      = [System.Collections.Generic.List[object]]::new()
    StartTlsResults   = [System.Collections.Generic.List[object]]::new()
    RootDseResults    = [System.Collections.Generic.List[object]]::new()
    ForestTrusts      = [System.Collections.Generic.List[object]]::new()
}

# --- DNS resolution ---
$dnsTargets = @(
    [ordered]@{ Name = 'MiSouleDC02.misoule02.local'; ExpectedDomain = 'misoule02.local' }
    [ordered]@{ Name = 'MiSouleDC03.child.misoule02.local'; ExpectedDomain = 'child.misoule02.local' }
    [ordered]@{ Name = 'MiSouleDC04.misoule03.local'; ExpectedDomain = 'misoule03.local' }
)

foreach ($dt in $dnsTargets) {
    try {
        $resolved = Resolve-DnsName -Name $dt.Name -Type A -ErrorAction Stop
        $ip = $resolved[0].IPAddress
        $output.DnsResults.Add([ordered]@{
            Target   = $dt.Name
            Resolved = $ip
            Success  = $true
        })
    }
    catch {
        $output.DnsResults.Add([ordered]@{
            Target   = $dt.Name
            Resolved = $null
            Success  = $false
            Error    = $_.Exception.Message
        })
    }
}

# --- Banned modules ---
$banned = @(Get-Module -ListAvailable -Name ActiveDirectory, GroupPolicy, DnsServer)
$output.BannedModuleCount = $banned.Count
foreach ($m in $banned) { $output.BannedModules.Add($m.Name) }

# --- Implicit auth state ---
$cs = Get-CimInstance Win32_ComputerSystem
$output.IsDomainJoined = $cs.PartOfDomain
if ($output.IsDomainJoined) { $output.JoinedDomain = $cs.Domain }

# --- Protocol path: LDAPS, StartTLS, RootDSE ---
Add-Type -AssemblyName System.DirectoryServices.Protocols

$dcEndpoints = @(
    [ordered]@{ Host = 'MiSouleDC02.misoule02.local'; ExpectedNC = 'DC=misoule02,DC=local' }
    [ordered]@{ Host = 'MiSouleDC03.child.misoule02.local'; ExpectedNC = 'DC=child,DC=misoule02,DC=local' }
    [ordered]@{ Host = 'MiSouleDC04.misoule03.local'; ExpectedNC = 'DC=misoule03,DC=local' }
)

foreach ($ep in $dcEndpoints) {
    # LDAPS on 636
    $ldapsConn = $null
    try {
        $id = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($ep.Host, 636, $false, $false)
        $ldapsConn = New-Object System.DirectoryServices.Protocols.LdapConnection($id)
        $ldapsConn.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $ldapsConn.SessionOptions.ProtocolVersion = 3
        $ldapsConn.SessionOptions.SecureSocketLayer = $true
        $ldapsConn.Bind()

        $search = New-Object System.DirectoryServices.Protocols.SearchRequest('', '(objectClass=*)', 'Base', @('defaultNamingContext'))
        $response = $ldapsConn.SendRequest($search)
        $rootDse = $response.Entries[0]
        $defaultNC = [string]$rootDse.Attributes['defaultNamingContext'][0]

        $output.LdapsResults.Add([ordered]@{
            Host       = $ep.Host
            Port       = 636
            TlsMode    = 'Ldaps'
            Success    = $true
            RootDseNC  = $defaultNC
            NcMatch    = ($defaultNC -eq $ep.ExpectedNC)
        })
    }
    catch {
        $output.LdapsResults.Add([ordered]@{
            Host    = $ep.Host
            Port    = 636
            TlsMode = 'Ldaps'
            Success = $false
            Error   = $_.Exception.Message
        })
    }
    finally {
        if ($null -ne $ldapsConn) { try { $ldapsConn.Dispose() } catch { } }
    }

    # StartTLS on 389
    $startTlsConn = $null
    try {
        $id2 = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($ep.Host, 389, $false, $false)
        $startTlsConn = New-Object System.DirectoryServices.Protocols.LdapConnection($id2)
        $startTlsConn.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $startTlsConn.SessionOptions.ProtocolVersion = 3
        $startTlsConn.SessionOptions.StartTransportLayerSecurity((New-Object System.DirectoryServices.Protocols.DirectoryControlCollection))
        $startTlsConn.Bind()

        $search2 = New-Object System.DirectoryServices.Protocols.SearchRequest('', '(objectClass=*)', 'Base', @('defaultNamingContext'))
        $response2 = $startTlsConn.SendRequest($search2)
        $rootDse2 = $response2.Entries[0]
        $defaultNC2 = [string]$rootDse2.Attributes['defaultNamingContext'][0]

        $output.StartTlsResults.Add([ordered]@{
            Host      = $ep.Host
            Port      = 389
            TlsMode   = 'StartTls'
            Success   = $true
            RootDseNC = $defaultNC2
            NcMatch   = ($defaultNC2 -eq $ep.ExpectedNC)
        })
    }
    catch {
        $output.StartTlsResults.Add([ordered]@{
            Host    = $ep.Host
            Port    = 389
            TlsMode = 'StartTls'
            Success = $false
            Error   = $_.Exception.Message
        })
    }
    finally {
        if ($null -ne $startTlsConn) { try { $startTlsConn.Dispose() } catch { } }
    }

    # RootDSE identity (canonical via protocol path on 636)
    $rootConn = $null
    try {
        $id3 = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($ep.Host, 636, $false, $false)
        $rootConn = New-Object System.DirectoryServices.Protocols.LdapConnection($id3)
        $rootConn.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $rootConn.SessionOptions.ProtocolVersion = 3
        $rootConn.SessionOptions.SecureSocketLayer = $true
        $rootConn.Bind()

        $search3 = New-Object System.DirectoryServices.Protocols.SearchRequest('', '(objectClass=*)', 'Base', @('defaultNamingContext','dnsHostName'))
        $response3 = $rootConn.SendRequest($search3)
        $entry3 = $response3.Entries[0]
        $defaultNC3 = [string]$entry3.Attributes['defaultNamingContext'][0]
        $dnsHost3 = [string]$entry3.Attributes['dnsHostName'][0]

        $output.RootDseResults.Add([ordered]@{
            Host           = $ep.Host
            DefaultNC      = $defaultNC3
            ExpectedNC     = $ep.ExpectedNC
            NcMatch        = ($defaultNC3 -eq $ep.ExpectedNC)
            DnsHostName    = $dnsHost3
            Success        = $true
        })
    }
    catch {
        $output.RootDseResults.Add([ordered]@{
            Host       = $ep.Host
            ExpectedNC = $ep.ExpectedNC
            Success    = $false
            Error      = $_.Exception.Message
        })
    }
    finally {
        if ($null -ne $rootConn) { try { $rootConn.Dispose() } catch { } }
    }
}

# --- Forest trust assertions ---
try {
    $trusts = nltest /domain_trusts /all_trusts 2>$null
    $parsed = foreach ($line in $trusts) {
        if ($line -match '^\s*0:\s+(.+?)\s+(.+?)\s+(.+?)\s+(.+?)\s+(.+)$') {
            [ordered]@{ Domain = $matches[1].Trim(); Type = $matches[2].Trim() }
        }
    }
    $output.ForestTrusts = [System.Collections.Generic.List[object]]::new()
    foreach ($t in $parsed) { $output.ForestTrusts.Add($t) }
}
catch {
    $output.ForestTrusts = [System.Collections.Generic.List[object]]::new()
}

# Fallback: query trustedDomain objects via LDAP on root DC
if ($output.ForestTrusts.Count -eq 0) {
    $trustConn = $null
    try {
        $tcId = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier('MiSouleDC02.misoule02.local', 636, $false, $false)
        $trustConn = New-Object System.DirectoryServices.Protocols.LdapConnection($tcId)
        $trustConn.AuthType = [System.DirectoryServices.Protocols.AuthType]::Negotiate
        $trustConn.SessionOptions.ProtocolVersion = 3
        $trustConn.SessionOptions.SecureSocketLayer = $true
        $trustConn.Bind()

        $tSearch = New-Object System.DirectoryServices.Protocols.SearchRequest(
            'CN=System,DC=misoule02,DC=local',
            '(objectClass=trustedDomain)',
            'Subtree',
            @('cn','trustPartner','trustType','trustDirection')
        )
        $tResponse = $trustConn.SendRequest($tSearch)
        foreach ($e in $tResponse.Entries) {
            $output.ForestTrusts.Add([ordered]@{
                Domain = [string]$e.Attributes['trustPartner'][0]
                Type   = [string]$e.Attributes['trustType'][0]
            })
        }
    }
    catch { }
    finally {
        if ($null -ne $trustConn) { try { $trustConn.Dispose() } catch { } }
    }
}

$output | ConvertTo-Json -Depth 10 -Compress
'@

$winRaw = Invoke-LabVmRunCommand -VmName 'MiSouleRunnerWin' -CommandId 'RunPowerShellScript' -ScriptContent $windowsRunnerScript
$winData = $winRaw | ConvertFrom-Json

# --- DNS checks (Windows runner) ---
foreach ($dns in $winData.DnsResults) {
    Add-PreflightCheck -List $results `
        -CheckId "DNS.Win.$($dns.Target)" `
        -Category 'DNS' `
        -Target $dns.Target `
        -Runner 'MiSouleRunnerWin' `
        -RequestedTarget $dns.Target `
        -ResolvedTarget $dns.Resolved `
        -Expected 'Resolvable' `
        -Actual $(if ($dns.Success) { 'Resolved' } else { 'Failed' }) `
        -Success ([bool]$dns.Success) `
        -Mandatory $true `
        -Details $(if ($dns.Error) { @{ Error = $dns.Error } } else { @{} })
}

# --- Banned modules (Windows runner) ---
Add-PreflightCheck -List $results `
    -CheckId 'BannedModules.Win' `
    -Category 'BannedModules' `
    -Target 'MiSouleRunnerWin' `
    -Runner 'MiSouleRunnerWin' `
    -Expected 0 `
    -Actual $winData.BannedModuleCount `
    -Success ($winData.BannedModuleCount -eq 0) `
    -Mandatory $true `
    -Details @{ BannedModules = [string[]]@($winData.BannedModules) }

# --- Implicit auth state (Windows runner) ---
Add-PreflightCheck -List $results `
    -CheckId 'AuthState.Win.DomainJoined' `
    -Category 'AuthState' `
    -Target 'MiSouleRunnerWin' `
    -Runner 'MiSouleRunnerWin' `
    -Expected 'misoule02.local' `
    -Actual $winData.JoinedDomain `
    -Success ($winData.IsDomainJoined -and $winData.JoinedDomain -eq 'misoule02.local') `
    -Mandatory $true `
    -Details @{ IsDomainJoined = [bool]$winData.IsDomainJoined }

# --- LDAPS checks ---
foreach ($ldaps in $winData.LdapsResults) {
    $certTrusted = [bool]$ldaps.Success
    $hostnameValid = [bool]$ldaps.NcMatch
    Add-PreflightCheck -List $results `
        -CheckId "LDAPS.$($ldaps.Host)" `
        -Category 'LDAPS' `
        -Target $ldaps.Host `
        -Runner 'MiSouleRunnerWin' `
        -RequestedTarget $ldaps.Host `
        -ResolvedTarget $(if ($certTrusted) { $ldaps.Host } else { $null }) `
        -Expected 'TlsSuccess+NcMatch' `
        -Actual $(if ($certTrusted -and $hostnameValid) { 'TlsSuccess+NcMatch' } elseif ($certTrusted) { 'TlsSuccess' } else { 'Failed' }) `
        -Success ($certTrusted -and $hostnameValid) `
        -Mandatory $true `
        -Details @{
            Port      = $ldaps.Port
            TlsMode   = $ldaps.TlsMode
            RootDseNC = $ldaps.RootDseNC
            NcMatch   = [bool]$ldaps.NcMatch
            Error     = $ldaps.Error
        }
}

# --- StartTLS checks ---
foreach ($stls in $winData.StartTlsResults) {
    $tlsOk = [bool]$stls.Success
    $ncOk = [bool]$stls.NcMatch
    Add-PreflightCheck -List $results `
        -CheckId "StartTLS.$($stls.Host)" `
        -Category 'StartTLS' `
        -Target $stls.Host `
        -Runner 'MiSouleRunnerWin' `
        -RequestedTarget $stls.Host `
        -ResolvedTarget $(if ($tlsOk) { $stls.Host } else { $null }) `
        -Expected 'TlsSuccess+NcMatch' `
        -Actual $(if ($tlsOk -and $ncOk) { 'TlsSuccess+NcMatch' } elseif ($tlsOk) { 'TlsSuccess' } else { 'Failed' }) `
        -Success ($tlsOk -and $ncOk) `
        -Mandatory $true `
        -Details @{
            Port      = $stls.Port
            TlsMode   = $stls.TlsMode
            RootDseNC = $stls.RootDseNC
            NcMatch   = [bool]$stls.NcMatch
            Error     = $stls.Error
        }
}

# --- RootDSE identity checks ---
foreach ($rd in $winData.RootDseResults) {
    Add-PreflightCheck -List $results `
        -CheckId "RootDSE.$($rd.Host)" `
        -Category 'RootDSE' `
        -Target $rd.Host `
        -Runner 'MiSouleRunnerWin' `
        -RequestedTarget $rd.Host `
        -ResolvedTarget $rd.DnsHostName `
        -Expected $rd.ExpectedNC `
        -Actual $rd.DefaultNC `
        -Success ([bool]$rd.Success -and [bool]$rd.NcMatch) `
        -Mandatory $true `
        -Details @{
            DnsHostName = $rd.DnsHostName
            NcMatch     = [bool]$rd.NcMatch
            Error       = $rd.Error
        }
}

# --- Forest trust assertions ---
$trustDomains = [string[]]@($winData.ForestTrusts | ForEach-Object { $_.Domain })
$childTrustPresent = $trustDomains -contains 'child.misoule02.local'
$separateForestTrustAbsent = -not ($trustDomains -contains 'misoule03.local')

Add-PreflightCheck -List $results `
    -CheckId 'ForestTrust.ChildPresent' `
    -Category 'ForestTrust' `
    -Target 'misoule02.local -> child.misoule02.local' `
    -Runner 'MiSouleRunnerWin' `
    -Expected 'Present' `
    -Actual $(if ($childTrustPresent) { 'Present' } else { 'Absent' }) `
    -Success $childTrustPresent `
    -Mandatory $true `
    -Details @{ DiscoveredTrusts = $trustDomains }

Add-PreflightCheck -List $results `
    -CheckId 'ForestTrust.SeparateAbsent' `
    -Category 'ForestTrust' `
    -Target 'misoule02.local -> misoule03.local' `
    -Expected 'Absent' `
    -Actual $(if ($separateForestTrustAbsent) { 'Absent' } else { 'Present' }) `
    -Success $separateForestTrustAbsent `
    -Mandatory $true `
    -Details @{ DiscoveredTrusts = $trustDomains }

# ---------------------------------------------------------------------------
# 3) Linux runner comprehensive gate
# ---------------------------------------------------------------------------
$linuxRunnerScript = @'
set -euo pipefail

pwsh -NoLogo -NoProfile -Command '
$ErrorActionPreference = "Stop"

$output = [ordered]@{
    DnsResults        = [System.Collections.Generic.List[object]]::new()
    BannedModuleCount = 0
    BannedModules     = [System.Collections.Generic.List[string]]::new()
    PwshAvailable     = $false
    SmbClientAvailable= $false
    PSWSManAvailable  = $false
    RealmdEnrolled    = $false
    EnrolledDomain    = $null
}

# --- DNS resolution ---
$dnsTargets = @(
    [ordered]@{ Name = "MiSouleDC02.misoule02.local"; ExpectedDomain = "misoule02.local" }
    [ordered]@{ Name = "MiSouleDC03.child.misoule02.local"; ExpectedDomain = "child.misoule02.local" }
    [ordered]@{ Name = "MiSouleDC04.misoule03.local"; ExpectedDomain = "misoule03.local" }
)

foreach ($dt in $dnsTargets) {
    try {
        $resolved = Resolve-DnsName -Name $dt.Name -Type A -ErrorAction Stop
        $ip = $resolved[0].IPAddress
        $output.DnsResults.Add([ordered]@{
            Target   = $dt.Name
            Resolved = $ip
            Success  = $true
        })
    }
    catch {
        $output.DnsResults.Add([ordered]@{
            Target   = $dt.Name
            Resolved = $null
            Success  = $false
            Error    = $_.Exception.Message
        })
    }
}

# --- Banned modules ---
$banned = @(Get-Module -ListAvailable -Name ActiveDirectory, GroupPolicy, DnsServer)
$output.BannedModuleCount = $banned.Count
foreach ($m in $banned) { $output.BannedModules.Add($m.Name) }

# --- Tooling ---
$output.PwshAvailable = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
$output.SmbClientAvailable = [bool](Get-Command smbclient -ErrorAction SilentlyContinue)
$output.PSWSManAvailable = [bool](Get-Module -ListAvailable -Name PSWSMan)

# --- realmd / SSSD enrollment ---
try {
    $realmOutput = & realm list 2>$null
    if ($realmOutput -and $realmOutput -match "domain-name:\s+(\S+)") {
        $output.RealmdEnrolled = $true
        $output.EnrolledDomain = $matches[1]
    }
}
catch { }

$output | ConvertTo-Json -Depth 10 -Compress
'
'@

$linuxRaw = Invoke-LabVmRunCommand -VmName 'MiSouleRunnerLinux' -CommandId 'RunShellScript' -ScriptContent $linuxRunnerScript
$linuxData = $linuxRaw | ConvertFrom-Json

# --- DNS checks (Linux runner) ---
foreach ($dns in $linuxData.DnsResults) {
    Add-PreflightCheck -List $results `
        -CheckId "DNS.Linux.$($dns.Target)" `
        -Category 'DNS' `
        -Target $dns.Target `
        -Runner 'MiSouleRunnerLinux' `
        -RequestedTarget $dns.Target `
        -ResolvedTarget $dns.Resolved `
        -Expected 'Resolvable' `
        -Actual $(if ($dns.Success) { 'Resolved' } else { 'Failed' }) `
        -Success ([bool]$dns.Success) `
        -Mandatory $true `
        -Details $(if ($dns.Error) { @{ Error = $dns.Error } } else { @{} })
}

# --- Banned modules (Linux runner) ---
Add-PreflightCheck -List $results `
    -CheckId 'BannedModules.Linux' `
    -Category 'BannedModules' `
    -Target 'MiSouleRunnerLinux' `
    -Runner 'MiSouleRunnerLinux' `
    -Expected 0 `
    -Actual $linuxData.BannedModuleCount `
    -Success ($linuxData.BannedModuleCount -eq 0) `
    -Mandatory $true `
    -Details @{ BannedModules = [string[]]@($linuxData.BannedModules) }

# --- Tooling checks ---
Add-PreflightCheck -List $results `
    -CheckId 'AuthState.Linux.PSWSMan' `
    -Category 'AuthState' `
    -Target 'MiSouleRunnerLinux' `
    -Runner 'MiSouleRunnerLinux' `
    -Expected $true `
    -Actual ([bool]$linuxData.PSWSManAvailable) `
    -Success ([bool]$linuxData.PSWSManAvailable) `
    -Mandatory $true

Add-PreflightCheck -List $results `
    -CheckId 'AuthState.Linux.SmbClient' `
    -Category 'AuthState' `
    -Target 'MiSouleRunnerLinux' `
    -Runner 'MiSouleRunnerLinux' `
    -Expected $true `
    -Actual ([bool]$linuxData.SmbClientAvailable) `
    -Success ([bool]$linuxData.SmbClientAvailable) `
    -Mandatory $true

Add-PreflightCheck -List $results `
    -CheckId 'AuthState.Linux.Realmd' `
    -Category 'AuthState' `
    -Target 'MiSouleRunnerLinux' `
    -Runner 'MiSouleRunnerLinux' `
    -Expected 'misoule02.local' `
    -Actual $linuxData.EnrolledDomain `
    -Success ([bool]$linuxData.RealmdEnrolled -and $linuxData.EnrolledDomain -eq 'misoule02.local') `
    -Mandatory $true `
    -Details @{ RealmdEnrolled = [bool]$linuxData.RealmdEnrolled }

# ---------------------------------------------------------------------------
# 4) Assemble artifact and gate
# ---------------------------------------------------------------------------
$mandatoryFailures = @($results | Where-Object { $_.Mandatory -and -not $_.Success })
$optionalFailures  = @($results | Where-Object { -not $_.Mandatory -and -not $_.Success })

$artifact = [ordered]@{
    Timestamp       = [datetime]::UtcNow.ToString('o')
    LabId           = $TagValue
    ResourceGroup   = $ResourceGroupName
    OverallSuccess  = ($mandatoryFailures.Count -eq 0)
    Summary         = [ordered]@{
        TotalChecks        = $results.Count
        PassedCount        = @($results | Where-Object { $_.Success }).Count
        FailedCount        = @($results | Where-Object { -not $_.Success }).Count
        MandatoryFailedCount = $mandatoryFailures.Count
        OptionalFailedCount  = $optionalFailures.Count
        BannedModuleCountWin = ($results | Where-Object { $_.CheckId -eq 'BannedModules.Win' }).Actual
        BannedModuleCountLinux = ($results | Where-Object { $_.CheckId -eq 'BannedModules.Linux' }).Actual
    }
    RunnerState     = [ordered]@{
        Windows = [ordered]@{
            DomainJoined     = ($results | Where-Object { $_.CheckId -eq 'AuthState.Win.DomainJoined' }).Success
            BannedModulesOk  = ($results | Where-Object { $_.CheckId -eq 'BannedModules.Win' }).Success
        }
        Linux   = [ordered]@{
            PSWSManOk        = ($results | Where-Object { $_.CheckId -eq 'AuthState.Linux.PSWSMan' }).Success
            SmbClientOk      = ($results | Where-Object { $_.CheckId -eq 'AuthState.Linux.SmbClient' }).Success
            RealmdOk         = ($results | Where-Object { $_.CheckId -eq 'AuthState.Linux.Realmd' }).Success
            BannedModulesOk  = ($results | Where-Object { $_.CheckId -eq 'BannedModules.Linux' }).Success
        }
    }
    AuthTlsAssertions = [ordered]@{
        LdapsTrustedAll    = -not @($results | Where-Object { $_.Category -eq 'LDAPS' -and -not $_.Success }).Count
        StartTlsSuccessAll = -not @($results | Where-Object { $_.Category -eq 'StartTLS' -and -not $_.Success }).Count
        RootDseMatchedAll  = -not @($results | Where-Object { $_.Category -eq 'RootDSE' -and -not $_.Success }).Count
        DnsResolvedAll     = -not @($results | Where-Object { $_.Category -eq 'DNS' -and -not $_.Success }).Count
    }
    Checks          = [object[]]@($results)
}

if (-not (Test-Path -LiteralPath $EvidencePath)) {
    New-Item -ItemType Directory -Path $EvidencePath -Force | Out-Null
}

$artifactFile = Join-Path $EvidencePath ('preflight-{0}.json' -f $TagValue)
$artifact | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $artifactFile -Encoding utf8NoBOM

Write-Host "`n=== Lab Preflight Gate ===" -ForegroundColor Cyan
Write-Host "Artifact: $artifactFile" -ForegroundColor Gray
Write-Host "Total checks: $($artifact.Summary.TotalChecks)" -ForegroundColor Gray
Write-Host "Passed: $($artifact.Summary.PassedCount)" -ForegroundColor Gray
Write-Host "Failed (mandatory): $($artifact.Summary.MandatoryFailedCount)" -ForegroundColor $(if ($artifact.Summary.MandatoryFailedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "Failed (optional): $($artifact.Summary.OptionalFailedCount)" -ForegroundColor $(if ($artifact.Summary.OptionalFailedCount -gt 0) { 'Yellow' } else { 'Green' })

if ($mandatoryFailures.Count -gt 0) {
    Write-Host "`nMandatory failures:" -ForegroundColor Red
    foreach ($f in $mandatoryFailures) {
        Write-Host "  [$($f.CheckId)] $($f.Category) / $($f.Target) -> Expected: $($f.Expected), Actual: $($f.Actual)" -ForegroundColor Red
    }
    throw ('Lab preflight gate FAILED. Mandatory checks failed: ' + ($mandatoryFailures.CheckId -join ', '))
}

Write-Host "`nLab preflight gate PASSED. All mandatory checks succeeded." -ForegroundColor Green
return $artifact
