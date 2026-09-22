<#
.SYNOPSIS
    Creates and configures a Windows or Ubuntu runner VM for the lab.

.DESCRIPTION
    Creates the runner NIC, public IP, and VM, then applies the platform-
    specific configuration required for Maester Active Directory protocol-based
    testing. Windows runners get WinRM HTTPS and explicit checks that the banned
    management modules are not present. Ubuntu runners get PowerShell, smbclient,
    PSWSMan, and imported LDAPS trust anchors.

.PARAMETER OsType
    Runner operating system. Supported values are Windows and Ubuntu.

.PARAMETER TrustedCertificateBase64
    Base64-encoded public certificates trusted by the runner for LDAPS/StartTLS.

.PARAMETER ComputerName
    Guest operating system name. This permits a Windows computer name of at most
    15 characters while retaining a longer canonical Azure VM resource name.

.PARAMETER DomainName
    Optional root domain to join after runner configuration. Windows uses
    Add-Computer; Ubuntu uses realmd/SSSD so a PowerShell process launched as a
    domain user has a Kerberos-backed implicit credential.

.EXAMPLE
    ./New-RunnerVm.ps1 -VmName MiSouleRunnerLinux -OsType Ubuntu -PrivateIpAddress 10.20.0.11

    Creates the Ubuntu runner and installs PSWSMan plus smbclient.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'AdminPassword',
    Justification = 'Azure CLI VM creation requires a plain-text password argument at execution time.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingPlainTextForPassword',
    'DomainJoinPassword',
    Justification = 'The password is passed to the remote domain-join operation at execution time.'
)]
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ResourceGroupName = 'RG_5100_MiSoule_2',

    [Parameter()]
    [string]$Location = 'eastus',

    [Parameter()]
    [string]$VNetName = 'MiSouleADTestVNet',

    [Parameter()]
    [string]$SubnetName = 'LabSubnet',

    [Parameter(Mandatory)]
    [string]$VmName,

    [Parameter()]
    [string]$ComputerName,

    [Parameter(Mandatory)]
    [ValidateSet('Windows', 'Ubuntu')]
    [string]$OsType,

    [Parameter(Mandatory)]
    [string]$PrivateIpAddress,

    [Parameter()]
    [string[]]$DnsServer = @(),

    [Parameter()]
    [string]$AdminUsername = 'labadmin',

    [Parameter(Mandatory)]
    [string]$AdminPassword,

    [Parameter()]
    [string]$DomainName,

    [Parameter()]
    [string]$DomainJoinUsername,

    [Parameter()]
    [string]$DomainJoinPassword,

    [Parameter()]
    [string[]]$TrustedCertificateBase64 = @(),

    [Parameter()]
    [string[]]$Tag = @(),

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-LabAzCli {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter()]
        [switch]$ExpectJson,

        [Parameter()]
        [switch]$AllowFailure
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
    if ($exitCode -ne 0 -and $AllowFailure.IsPresent) {
        return $null
    }

    if ($exitCode -ne 0 -and -not $AllowFailure.IsPresent) {
        $redactedArguments = @($Arguments)
        $sensitiveValues = [System.Collections.Generic.List[string]]::new()
        for ($index = 0; $index -lt $redactedArguments.Count; $index++) {
            if ($index -gt 0 -and $redactedArguments[$index - 1] -match '(?i)^--(admin-password|password|value)$') {
                $sensitiveValues.Add($redactedArguments[$index])
                $redactedArguments[$index] = '[REDACTED]'
            } elseif ($redactedArguments[$index] -match '(?i)^(?<name>[^=]*(password|secret|token)[^=]*)=(?<value>.+)$') {
                $sensitiveValues.Add($Matches.value)
                $redactedArguments[$index] = $Matches.name + '=[REDACTED]'
            }
        }
        foreach ($sensitiveValue in $sensitiveValues) {
            $output = $output.Replace($sensitiveValue, '[REDACTED]')
        }
        throw "Azure CLI command failed ($exitCode): az $($redactedArguments -join ' ')`n$output"
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
        [string]$CommandId,

        [Parameter(Mandatory)]
        [string]$ScriptContent,

        [Parameter()]
        [hashtable]$Parameter = @{}
    )

    $temporaryFile = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -LiteralPath $temporaryFile -Value $ScriptContent -Encoding utf8

        $arguments = @(
            'vm', 'run-command', 'invoke',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName,
            '--command-id', $CommandId,
            '--scripts', ('@{0}' -f $temporaryFile),
            '--query', 'value[0].message',
            '--output', 'tsv'
        )

        if ($Parameter.Count -gt 0) {
            $arguments += '--parameters'
            foreach ($key in $Parameter.Keys) {
                $arguments += ('{0}={1}' -f $key, $Parameter[$key])
            }
        }

        return Invoke-LabAzCli -Arguments $arguments
    } finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

$publicIpName = '{0}-pip' -f $VmName
$nicName = '{0}-nic' -f $VmName
$effectiveComputerName = if ($ComputerName) { $ComputerName } else { $VmName }

if ($OsType -eq 'Windows' -and $effectiveComputerName.Length -gt 15) {
    throw "Windows computer name '$effectiveComputerName' exceeds the 15-character limit."
}

if ($DomainName -and (-not $DomainJoinUsername -or -not $DomainJoinPassword)) {
    throw 'DomainName requires DomainJoinUsername and DomainJoinPassword.'
}

$existingPublicIp = Invoke-LabAzCli -Arguments @(
    'network', 'public-ip', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $publicIpName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if (-not $existingPublicIp -and $PSCmdlet.ShouldProcess($publicIpName, 'Create runner public IP')) {
    $publicIpArguments = @(
        'network', 'public-ip', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $publicIpName,
        '--sku', 'Standard',
        '--allocation-method', 'Static',
        '--version', 'IPv4',
        '--tags'
    ) + $Tag + @('--output', 'none')

    Invoke-LabAzCli -Arguments $publicIpArguments | Out-Null
}

$existingNic = Invoke-LabAzCli -Arguments @(
    'network', 'nic', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $nicName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if (-not $existingNic -and $PSCmdlet.ShouldProcess($nicName, 'Create runner network interface')) {
    $nicArguments = @(
        'network', 'nic', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $nicName,
        '--vnet-name', $VNetName,
        '--subnet', $SubnetName,
        '--private-ip-address', $PrivateIpAddress,
        '--public-ip-address', $publicIpName,
        '--tags'
    ) + $Tag + @('--output', 'none')

    Invoke-LabAzCli -Arguments $nicArguments | Out-Null
}

if ($DnsServer.Count -gt 0) {
    $dnsUpdateArguments = @(
        'network', 'nic', 'update',
        '--resource-group', $ResourceGroupName,
        '--name', $nicName,
        '--dns-servers'
    ) + $DnsServer + @('--output', 'none')

    Invoke-LabAzCli -Arguments $dnsUpdateArguments | Out-Null
}

$existingVm = Invoke-LabAzCli -Arguments @(
    'vm', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $VmName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if ($existingVm) {
    if (-not $Force.IsPresent -and $existingVm.hardwareProfile.vmSize -ne 'Standard_D4s_v5') {
        throw "VM '$VmName' already exists with an unexpected size. Use -Force to continue."
    }
} elseif ($PSCmdlet.ShouldProcess($VmName, 'Create runner VM')) {
    $imageReference = if ($OsType -eq 'Windows') {
        'MicrosoftWindowsServer:WindowsServer:2022-datacenter-azure-edition:latest'
    } else {
        'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest'
    }

    $createVmArguments = @(
        'vm', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $VmName,
        '--image', $imageReference,
        '--size', 'Standard_D4s_v5',
        '--nics', $nicName,
        '--admin-username', $AdminUsername,
        '--admin-password', $AdminPassword,
        '--authentication-type', 'password',
        '--tags'
    ) + $Tag + @('--output', 'none')

    if ($OsType -eq 'Windows') {
        $createVmArguments += @('--computer-name', $effectiveComputerName)
    }

    Invoke-LabAzCli -Arguments $createVmArguments | Out-Null
}

if ($OsType -eq 'Windows') {
    $configureWinRmPath = Join-Path -Path $PSScriptRoot -ChildPath 'Configure-WinRM.ps1'
    $winRmScriptText = & $configureWinRmPath -ListenerDnsName $effectiveComputerName -EmitScript
    $winRmScriptBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($winRmScriptText))
    $trustedCertificateLiteral = @($TrustedCertificateBase64 | ForEach-Object { "'$_'" }) -join ', '

    $windowsConfigurationScript = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

`$winRmScriptText = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$winRmScriptBase64'))

`$trustedCertificates = @($trustedCertificateLiteral)
`$trustedRootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new('Root', 'LocalMachine')
`$trustedRootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
foreach (`$certificateValue in `$trustedCertificates) {
    if (-not [string]::IsNullOrWhiteSpace(`$certificateValue)) {
        `$certificateObject = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String(`$certificateValue))
        if (-not (`$trustedRootStore.Certificates | Where-Object { `$_.Thumbprint -eq `$certificateObject.Thumbprint })) {
            `$trustedRootStore.Add(`$certificateObject)
        }
    }
}
`$trustedRootStore.Close()

foreach (`$moduleName in @('ActiveDirectory', 'GroupPolicy', 'DnsServer')) {
    if (Get-Module -ListAvailable -Name `$moduleName) {
        throw "Runner must not have the `$moduleName module available."
    }
}

[scriptblock]::Create(`$winRmScriptText).Invoke() | Out-Null

[PSCustomObject]@{
    VmName = '$VmName'
    OsType = 'Windows'
    TrustedCertificateCount = `$trustedCertificates.Count
    WinRmHttpsConfigured = `$true
    BannedModuleCount = @(Get-Module -ListAvailable -Name ActiveDirectory, GroupPolicy, DnsServer).Count
} | ConvertTo-Json -Compress
"@

    Write-Verbose (Invoke-LabVmRunCommand -CommandId 'RunPowerShellScript' -ScriptContent $windowsConfigurationScript)

    if ($DomainName) {
        $domainJoinScript = @'
param($domainName, $domainJoinUsername, $domainJoinPassword)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
if ($computerSystem.PartOfDomain -and $computerSystem.Domain -eq $domainName) {
    'AlreadyJoined'
    return
}

$securePassword = ConvertTo-SecureString -String $domainJoinPassword -AsPlainText -Force
$credential = [System.Management.Automation.PSCredential]::new($domainJoinUsername, $securePassword)
Add-Computer -DomainName $domainName -Credential $credential -Force
'Joined'
'@
        $joinResult = Invoke-LabVmRunCommand -CommandId 'RunPowerShellScript' -ScriptContent $domainJoinScript -Parameter @{
            domainName         = $DomainName
            domainJoinUsername = $DomainJoinUsername
            domainJoinPassword = $DomainJoinPassword
        }
        if ($joinResult -match '(?m)^Joined\r?$') {
            Invoke-LabAzCli -Arguments @('vm', 'restart', '--resource-group', $ResourceGroupName, '--name', $VmName, '--output', 'none') | Out-Null
        }
    }
} else {
    $installPsWsManPath = Join-Path -Path $PSScriptRoot -ChildPath 'Install-PSWSMan.ps1'
    $baseInstallScript = & $installPsWsManPath -EmitScript
    $realmJoinUsername = if ($DomainJoinUsername) {
        (($DomainJoinUsername -split '@')[0] -split '\\')[-1]
    } else {
        ''
    }
    $linuxConfigurationScript = @'
set -euo pipefail

__INSTALL_SCRIPT__

sudo install -d -m 0755 /usr/local/share/ca-certificates/maester-lab
cat <<'CERTS' | sudo tee /usr/local/share/ca-certificates/maester-lab/certificates.json >/dev/null
__CERTIFICATES_JSON__
CERTS

python3 - <<'PYCODE'
import base64
import json
from pathlib import Path

certificate_directory = Path('/usr/local/share/ca-certificates/maester-lab')
certificate_values = json.loads((certificate_directory / 'certificates.json').read_text())
for index, value in enumerate(certificate_values, start=1):
    if value:
        der_value = base64.b64decode(value)
        pem_value = base64.b64encode(der_value).decode('ascii')
        pem_lines = [pem_value[offset:offset + 64] for offset in range(0, len(pem_value), 64)]
        certificate_text = '-----BEGIN CERTIFICATE-----\n' + '\n'.join(pem_lines) + '\n-----END CERTIFICATE-----\n'
        (certificate_directory / f'lab-{index}.crt').write_text(certificate_text)
PYCODE

sudo update-ca-certificates
pwsh -NoLogo -NoProfile -Command "if ((Get-Module -ListAvailable -Name ActiveDirectory,GroupPolicy,DnsServer).Count -ne 0) { throw 'Banned modules were found on the Ubuntu runner.' }"

if [ -n '__DOMAIN_NAME__' ]; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y realmd sssd-ad sssd-tools adcli krb5-user packagekit
    if ! realm list --name-only | grep -Fxqi '__DOMAIN_NAME__'; then
        printf '%s' "$1" | sudo realm join --user='__REALM_JOIN_USERNAME__' '__DOMAIN_NAME__'
    fi
    sudo realm permit '__DOMAIN_JOIN_USERNAME__'
    realm list
    getent passwd '__DOMAIN_JOIN_USERNAME__'
fi
'@

    $linuxConfigurationScript = $linuxConfigurationScript.Replace('__INSTALL_SCRIPT__', $baseInstallScript.TrimEnd())
    $linuxConfigurationScript = $linuxConfigurationScript.Replace('__CERTIFICATES_JSON__', (ConvertTo-Json -InputObject @($TrustedCertificateBase64) -Compress))
    $linuxConfigurationScript = $linuxConfigurationScript.Replace('__DOMAIN_NAME__', $DomainName)
    $linuxConfigurationScript = $linuxConfigurationScript.Replace('__DOMAIN_JOIN_USERNAME__', $DomainJoinUsername)
    $linuxConfigurationScript = $linuxConfigurationScript.Replace('__REALM_JOIN_USERNAME__', $realmJoinUsername)
    $linuxParameters = if ($DomainName) { @{ domainJoinPassword = $DomainJoinPassword } } else { @{} }
    Write-Verbose (Invoke-LabVmRunCommand -CommandId 'RunShellScript' -ScriptContent $linuxConfigurationScript -Parameter $linuxParameters)
}

$publicIpAddress = Invoke-LabAzCli -Arguments @(
    'network', 'public-ip', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $publicIpName,
    '--query', 'ipAddress',
    '--output', 'tsv'
)

[PSCustomObject]@{
    VmName           = $VmName
    ComputerName     = $effectiveComputerName
    OsType           = $OsType
    PrivateIpAddress = $PrivateIpAddress
    PublicIpAddress  = $publicIpAddress
}
