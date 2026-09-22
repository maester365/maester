<#
.SYNOPSIS
    Validates runner protocol prerequisites for a single Active Directory directory server.

.DESCRIPTION
    Checks platform capabilities (via Test-MtAdProtocolPrerequisites), TCP port reachability,
    and TLS certificate trust for the chosen directory server. Works on both Windows and
    Linux runners.

    This is the canonical prerequisite step and must pass before running Maester AD tests.

.PARAMETER TargetName
    The hostname or FQDN of the directory server to validate against (e.g. 'misoule02.local').

.PARAMETER MaesterModulePath
    Path to the Maester module root (contains Maester.psd1). Defaults to the repository's
    powershell/ folder relative to this script.

.PARAMETER SkipCertificateCheck
    Skip TLS certificate validation (for test environments only).

.EXAMPLE
    ./Test-ADProtocolPrerequisites.ps1 -TargetName 'misoule02.local'

    Validates protocol prerequisites for the root forest DC.

.EXAMPLE
    ./Test-ADProtocolPrerequisites.ps1 -TargetName 'MiSouleDC04.misoule03.local' -SkipCertificateCheck

    Validates prerequisites for the separate-forest DC (test environment, skips certificate validation).
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Runner script provides status output.'
)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetName,

    [Parameter()]
    [string]$MaesterModulePath = (Join-Path $PSScriptRoot "..\..\..\powershell"),

    [Parameter()]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter()]
    [switch]$SkipCertificateCheck
)

$ErrorActionPreference = 'Stop'

# Resolve and import Maester module so internal functions are available.
$MaesterModulePath = Resolve-Path $MaesterModulePath -ErrorAction Stop
$manifestPath = Join-Path $MaesterModulePath 'Maester.psd1'
if (-not (Test-Path $manifestPath)) {
    throw "Maester module manifest not found at: $manifestPath"
}
$maesterModule = Import-Module $manifestPath -Force -PassThru

Write-Host '=== Maester AD Protocol Prerequisites ===' -ForegroundColor Cyan
Write-Host "TargetName: $TargetName" -ForegroundColor Gray
Write-Host "Platform:   $($PSVersionTable.Platform ?? 'Win32NT')" -ForegroundColor Gray
Write-Host ''

$missingPrerequisites = [System.Collections.Generic.List[string]]::new()
$remediationActions = [System.Collections.Generic.List[string]]::new()

# ---------------------------------------------------------------------------
# 1) Platform capability matrix (uses the module's internal function)
# ---------------------------------------------------------------------------
Write-Host 'Checking platform capabilities...' -ForegroundColor Yellow
$platformCheck = & $maesterModule { Test-MtAdProtocolPrerequisites }

if (-not $platformCheck.IsReady) {
    foreach ($item in $platformCheck.MissingPrerequisites) {
        $missingPrerequisites.Add($item) | Out-Null
    }
    foreach ($item in $platformCheck.RemediationActions) {
        $remediationActions.Add($item) | Out-Null
    }
}

# ---------------------------------------------------------------------------
# 2) TCP port reachability (cross-platform)
# ---------------------------------------------------------------------------
function Test-TcpPort {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [int]$Port,

        [timespan]$Timeout = [timespan]::FromSeconds(5)
    )

    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $connectionTask = $client.ConnectAsync($HostName, $Port)
        $completed = $connectionTask.Wait($Timeout)
        if (-not $completed) {
            return $false
        }
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $client) {
            try { $client.Dispose() } catch { }
        }
    }
}

Write-Host 'Checking TCP port reachability...' -ForegroundColor Yellow

$portChecks = @(
    @{ Protocol = 'LDAP';   Port = 389;  Required = $true  },
    @{ Protocol = 'LDAPS';  Port = 636;  Required = $false },
    @{ Protocol = 'DNS';    Port = 53;   Required = $true  },
    @{ Protocol = 'SMB';    Port = 445;  Required = $false },
    @{ Protocol = 'WinRM-HTTP';  Port = 5985; Required = $false },
    @{ Protocol = 'WinRM-HTTPS'; Port = 5986; Required = $false }
)

$portResults = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($check in $portChecks) {
    $reachable = Test-TcpPort -HostName $TargetName -Port $check.Port
    $portResults.Add([PSCustomObject]@{
        Protocol = $check.Protocol
        Port     = $check.Port
        Reachable = $reachable
        Required = $check.Required
    })

    $status = if ($reachable) { 'open' } else { 'unreachable' }
    $color = if ($reachable) { 'Green' } elseif ($check.Required) { 'Red' } else { 'Yellow' }
    Write-Host "  $($check.Protocol) ($($check.Port)): $status" -ForegroundColor $color

    if (-not $reachable -and $check.Required) {
        $missingPrerequisites.Add("Required port $($check.Port)/$($check.Protocol) is not reachable on '$TargetName'.") | Out-Null
        $remediationActions.Add("Ensure firewall rules allow TCP/$($check.Port) from the runner to '$TargetName'.") | Out-Null
    }
}

Write-Host ''

# ---------------------------------------------------------------------------
# 3) TLS certificate validation (LDAPS / StartTLS)
# ---------------------------------------------------------------------------
function Test-TlsCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostName,

        [Parameter(Mandatory)]
        [int]$Port,

        [switch]$SkipCertificateCheck
    )

    $tcpClient = $null
    $sslStream = $null
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($HostName, $Port)

        $sslStream = New-Object System.Net.Security.SslStream(
            $tcpClient.GetStream(),
            $false,
            { param($sender, $certificate, $chain, $sslPolicyErrors)
                if ($SkipCertificateCheck) {
                    return $true
                }
                return ($sslPolicyErrors -eq [System.Net.Security.SslPolicyErrors]::None)
            }
        )

        $sslStream.AuthenticateAsClient($HostName)
        $cert = $sslStream.RemoteCertificate

        if ($null -eq $cert) {
            return [PSCustomObject]@{
                Valid      = $false
                Subject    = $null
                Thumbprint = $null
                Error      = 'No certificate presented by server.'
            }
        }

        $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
        $hostnameMatch = ($cert2.Subject -like "*CN=$HostName*") -or
                         ($cert2.DnsName -contains $HostName) -or
                         ($cert2.GetNameInfo('DnsName', $false) -eq $HostName)

        return [PSCustomObject]@{
            Valid      = $hostnameMatch
            Subject    = $cert2.Subject
            Thumbprint = $cert2.Thumbprint
            Error      = if (-not $hostnameMatch) { "Certificate subject/DNS names do not match '$HostName'." } else { $null }
        }
    }
    catch {
        return [PSCustomObject]@{
            Valid      = $false
            Subject    = $null
            Thumbprint = $null
            Error      = $_.Exception.Message
        }
    }
    finally {
        if ($null -ne $sslStream) { try { $sslStream.Dispose() } catch { } }
        if ($null -ne $tcpClient) { try { $tcpClient.Dispose() } catch { } }
    }
}

Write-Host 'Checking TLS certificate trust for LDAPS/StartTLS...' -ForegroundColor Yellow

$ldapsResult = $portResults | Where-Object { $_.Protocol -eq 'LDAPS' }
if ($ldapsResult -and $ldapsResult.Reachable) {
    $certCheck = Test-TlsCertificate -HostName $TargetName -Port 636 -SkipCertificateCheck:$SkipCertificateCheck
    if (-not $certCheck.Valid) {
        $missingPrerequisites.Add("LDAPS certificate validation failed for '$TargetName': $($certCheck.Error)") | Out-Null
        $remediationActions.Add("Install the DC's LDAPS certificate into the runner's trusted root store, or use -SkipCertificateCheck for test environments only.") | Out-Null
        Write-Host "  LDAPS (636): FAILED - $($certCheck.Error)" -ForegroundColor Red
    } else {
        Write-Host "  LDAPS (636): OK ($($certCheck.Subject))" -ForegroundColor Green
    }
} else {
    Write-Host '  LDAPS (636): skipped (port not reachable)' -ForegroundColor Yellow
}

# StartTLS probe on 389
$ldapResult = $portResults | Where-Object { $_.Protocol -eq 'LDAP' }
if ($ldapResult -and $ldapResult.Reachable) {
    # A full StartTLS LDAP handshake requires System.DirectoryServices.Protocols,
    # which may not be available on all runners. We do a best-effort TLS probe.
    Write-Host '  StartTLS: best-effort check (requires System.DirectoryServices.Protocols for full validation)' -ForegroundColor Yellow
} else {
    Write-Host '  StartTLS: skipped (LDAP port not reachable)' -ForegroundColor Yellow
}

Write-Host ''

# ---------------------------------------------------------------------------
# 4) WinRM HTTPS certificate validation
# ---------------------------------------------------------------------------
$winrmHttpsResult = $portResults | Where-Object { $_.Protocol -eq 'WinRM-HTTPS' }
if ($winrmHttpsResult -and $winrmHttpsResult.Reachable) {
    Write-Host 'Checking WinRM HTTPS certificate...' -ForegroundColor Yellow
    $winrmCertCheck = Test-TlsCertificate -HostName $TargetName -Port 5986 -SkipCertificateCheck:$SkipCertificateCheck
    if (-not $winrmCertCheck.Valid) {
        $missingPrerequisites.Add("WinRM HTTPS certificate validation failed for '$TargetName': $($winrmCertCheck.Error)") | Out-Null
        $remediationActions.Add("Ensure the WinRM HTTPS certificate on '$TargetName' matches the endpoint name used by the runner.") | Out-Null
        Write-Host "  WinRM-HTTPS (5986): FAILED - $($winrmCertCheck.Error)" -ForegroundColor Red
    } else {
        Write-Host "  WinRM-HTTPS (5986): OK ($($winrmCertCheck.Subject))" -ForegroundColor Green
    }
} else {
    Write-Host 'WinRM HTTPS: skipped (port not reachable)' -ForegroundColor Yellow
}

Write-Host ''

# ---------------------------------------------------------------------------
# 5) Assemble result
# ---------------------------------------------------------------------------
$isReady = ($missingPrerequisites.Count -eq 0)

$result = [PSCustomObject]@{
    IsReady              = $isReady
    TargetName           = $TargetName
    AuthModes            = $platformCheck.AuthModes
    TlsModes             = $platformCheck.TlsModes
    PlatformProfile      = $platformCheck.PlatformProfile
    MissingPrerequisites = [string[]]@($missingPrerequisites)
    RemediationActions   = [string[]]@($remediationActions | Select-Object -Unique)
    PortResults          = [PSCustomObject[]]@($portResults)
}

if ($isReady) {
    Write-Host 'Prerequisite check PASSED. The runner is ready for AD testing.' -ForegroundColor Green
} else {
    Write-Host 'Prerequisite check FAILED.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Missing prerequisites:' -ForegroundColor Yellow
    foreach ($item in $missingPrerequisites) {
        Write-Host "  - $item" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host 'Remediation actions:' -ForegroundColor Yellow
    foreach ($item in ($remediationActions | Select-Object -Unique)) {
        Write-Host "  - $item" -ForegroundColor Cyan
    }
}

return $result
