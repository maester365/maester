<#
.SYNOPSIS
    Configures WinRM HTTPS and Negotiate for a Windows host.

.DESCRIPTION
    Can either emit a reusable PowerShell script for Azure VM run-command usage
    or configure the current machine directly. The generated script enables
    PowerShell remoting, creates a self-signed certificate for the requested DNS
    name, binds a WinRM HTTPS listener, and enables Negotiate authentication.

.PARAMETER ListenerDnsName
    DNS name written into the self-signed WinRM listener certificate.

.PARAMETER FriendlyName
    Friendly name assigned to the generated certificate.

.PARAMETER EmitScript
    Output the configuration script instead of executing it locally.

.EXAMPLE
    ./Configure-WinRM.ps1 -ListenerDnsName MSRunnerWin -EmitScript

    Emits a PowerShell script string that can be passed to az vm run-command.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ListenerDnsName = $env:COMPUTERNAME,

    [Parameter()]
    [string]$FriendlyName = 'Maester Lab WinRM HTTPS',

    [Parameter()]
    [switch]$EmitScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WinRMConfigurationScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DnsName,

        [Parameter(Mandatory)]
        [string]$CertificateFriendlyName
    )

    $template = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$listenerDnsName = '__DNS_NAME__'
$friendlyName = '__FRIENDLY_NAME__'

Enable-PSRemoting -Force
Set-Item -Path WSMan:\localhost\Service\AllowUnencrypted -Value $false
Set-Item -Path WSMan:\localhost\Service\Auth\Basic -Value $false
Set-Item -Path WSMan:\localhost\Service\Auth\Kerberos -Value $true
Set-Item -Path WSMan:\localhost\Service\Auth\Negotiate -Value $true

$certificate = Get-ChildItem -Path Cert:\LocalMachine\My |
    Where-Object {
        $_.FriendlyName -eq $friendlyName -and
        $_.Subject -eq ('CN=' + $listenerDnsName)
    } |
    Select-Object -First 1

if (-not $certificate) {
    $certificateParameters = @{
        DnsName           = $listenerDnsName
        CertStoreLocation = 'Cert:\LocalMachine\My'
        FriendlyName      = $friendlyName
        KeyAlgorithm      = 'RSA'
        KeyLength         = 2048
        NotAfter          = (Get-Date).AddDays(14)
    }

    $certificate = New-SelfSignedCertificate @certificateParameters
}

$listener = Get-ChildItem -Path WSMan:\LocalHost\Listener |
    Where-Object { $_.Keys -match 'Transport=HTTPS' } |
    Select-Object -First 1

if ($listener) {
    Remove-Item -Path $listener.PSPath -Recurse -Force
}

$listenerParameters = @{
    Path                  = 'WSMan:\LocalHost\Listener'
    Transport             = 'HTTPS'
    Address               = '*'
    CertificateThumbPrint = $certificate.Thumbprint
    Force                 = $true
}

New-Item @listenerParameters | Out-Null

$firewallRule = Get-NetFirewallRule -DisplayName 'Maester Lab WinRM HTTPS' -ErrorAction SilentlyContinue
if (-not $firewallRule) {
    $firewallParameters = @{
        DisplayName = 'Maester Lab WinRM HTTPS'
        Direction   = 'Inbound'
        Protocol    = 'TCP'
        LocalPort   = 5986
        Action      = 'Allow'
    }

    New-NetFirewallRule @firewallParameters | Out-Null
}

[PSCustomObject]@{
    ListenerDnsName        = $listenerDnsName
    CertificateThumbprint  = $certificate.Thumbprint
    CertificateBase64      = [Convert]::ToBase64String($certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    NegotiateEnabled       = (Get-Item -Path WSMan:\localhost\Service\Auth\Negotiate).Value
    HttpsListenerConfigured = $true
} | ConvertTo-Json -Compress
'@

    return $template.Replace('__DNS_NAME__', $DnsName.Replace("'", "''")).Replace('__FRIENDLY_NAME__', $CertificateFriendlyName.Replace("'", "''"))
}

$scriptText = Get-WinRMConfigurationScript -DnsName $ListenerDnsName -CertificateFriendlyName $FriendlyName

if ($EmitScript.IsPresent) {
    return $scriptText
}

[scriptblock]::Create($scriptText).Invoke()
