<#
.SYNOPSIS
    Creates the Azure virtual network and NSG for the Maester E2E lab.

.DESCRIPTION
    Creates or validates the fixed lab virtual network, subnet, and network
    security group. The NSG only allows management traffic from the executor IP
    and permits east-west lab traffic inside the subnet.

.PARAMETER ResourceGroupName
    Existing Azure resource group that contains the lab.

.PARAMETER Location
    Azure region for the network resources.

.PARAMETER VNetName
    Virtual network name.

.PARAMETER AddressPrefix
    VNet CIDR block.

.PARAMETER SubnetName
    Subnet name for the lab.

.PARAMETER SubnetPrefix
    Subnet CIDR block.

.PARAMETER NsgName
    Network security group name.

.PARAMETER ExecutorPublicIp
    Executor IP address or CIDR allowed to manage the runners.

.PARAMETER DnsServer
    DNS resolver addresses advertised by the VNet. The root domain controller
    is the canonical resolver and forwards the child and separate-forest zones.

.PARAMETER Tag
    Azure resource tags in key=value format.

.EXAMPLE
    ./New-LabVNet.ps1 -ExecutorPublicIp 203.0.113.10/32

    Creates the lab VNet, subnet, and NSG rules.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$ResourceGroupName = 'RG_5100_MiSoule_2',

    [Parameter()]
    [string]$Location = 'eastus',

    [Parameter()]
    [string]$VNetName = 'MiSouleADTestVNet',

    [Parameter()]
    [string]$AddressPrefix = '10.20.0.0/24',

    [Parameter()]
    [string]$SubnetName = 'LabSubnet',

    [Parameter()]
    [string]$SubnetPrefix = '10.20.0.0/24',

    [Parameter()]
    [string]$NsgName = 'MiSouleADTestNsg',

    [Parameter(Mandatory)]
    [string]$ExecutorPublicIp,

    [Parameter()]
    [string[]]$DnsServer = @(),

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
        throw "Azure CLI command failed ($exitCode): az $($Arguments -join ' ')`n$output"
    }

    if ($ExpectJson.IsPresent -and $output) {
        return $output | ConvertFrom-Json
    }

    return $output
}

function Set-LabNsgRule {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$RuleName,

        [Parameter(Mandatory)]
        [int]$Priority,

        [Parameter(Mandatory)]
        [string]$Protocol,

        [Parameter(Mandatory)]
        [string[]]$SourceAddressPrefix,

        [Parameter(Mandatory)]
        [string[]]$DestinationPortRange,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $existingRule = Invoke-LabAzCli -Arguments @(
        'network', 'nsg', 'rule', 'show',
        '--resource-group', $ResourceGroupName,
        '--nsg-name', $NsgName,
        '--name', $RuleName,
        '--output', 'json'
    ) -AllowFailure -ExpectJson

    $baseArguments = @(
        'network', 'nsg', 'rule', $(if ($existingRule) { 'update' } else { 'create' }),
        '--resource-group', $ResourceGroupName,
        '--nsg-name', $NsgName,
        '--name', $RuleName,
        '--priority', $Priority.ToString(),
        '--direction', 'Inbound',
        '--access', 'Allow',
        '--protocol', $Protocol,
        '--source-address-prefixes'
    ) + $SourceAddressPrefix + @(
        '--source-port-ranges', '*',
        '--destination-address-prefixes', '*',
        '--destination-port-ranges'
    ) + $DestinationPortRange + @(
        '--description', $Description,
        '--output', 'none'
    )

    if ($PSCmdlet.ShouldProcess($RuleName, 'Create or update NSG rule')) {
        Invoke-LabAzCli -Arguments $baseArguments | Out-Null
    }
}

$executorCidr = if ($ExecutorPublicIp.Contains('/')) { $ExecutorPublicIp } else { '{0}/32' -f $ExecutorPublicIp }

$resourceGroup = Invoke-LabAzCli -Arguments @('group', 'show', '--name', $ResourceGroupName, '--output', 'json') -ExpectJson
if ($resourceGroup.location -ne $Location) {
    throw "Resource group '$ResourceGroupName' is in '$($resourceGroup.location)', not '$Location'."
}

$existingVnet = Invoke-LabAzCli -Arguments @(
    'network', 'vnet', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $VNetName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if ($existingVnet) {
    $existingAddressSpace = @($existingVnet.addressSpace.addressPrefixes)
    if (-not $Force.IsPresent -and ($existingAddressSpace -notcontains $AddressPrefix)) {
        throw "VNet '$VNetName' already exists but does not match the expected address space '$AddressPrefix'."
    }
} elseif ($PSCmdlet.ShouldProcess($VNetName, 'Create Azure virtual network')) {
    $createVnetArguments = @(
        'network', 'vnet', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $VNetName,
        '--address-prefixes', $AddressPrefix,
        '--subnet-name', $SubnetName,
        '--subnet-prefixes', $SubnetPrefix,
        '--tags'
    ) + $Tag + @('--output', 'none')

    Invoke-LabAzCli -Arguments $createVnetArguments | Out-Null
}

if ($DnsServer.Count -gt 0 -and $PSCmdlet.ShouldProcess($VNetName, 'Configure canonical lab DNS resolvers')) {
    $dnsArguments = @(
        'network', 'vnet', 'update',
        '--resource-group', $ResourceGroupName,
        '--name', $VNetName,
        '--dns-servers'
    ) + $DnsServer + @('--output', 'none')

    Invoke-LabAzCli -Arguments $dnsArguments | Out-Null
}

$existingNsg = Invoke-LabAzCli -Arguments @(
    'network', 'nsg', 'show',
    '--resource-group', $ResourceGroupName,
    '--name', $NsgName,
    '--output', 'json'
) -AllowFailure -ExpectJson

if (-not $existingNsg -and $PSCmdlet.ShouldProcess($NsgName, 'Create Azure network security group')) {
    $createNsgArguments = @(
        'network', 'nsg', 'create',
        '--resource-group', $ResourceGroupName,
        '--location', $Location,
        '--name', $NsgName,
        '--tags'
    ) + $Tag + @('--output', 'none')

    Invoke-LabAzCli -Arguments $createNsgArguments | Out-Null
}

if ($PSCmdlet.ShouldProcess($NsgName, 'Configure NSG rules for executor and lab subnet')) {
    Set-LabNsgRule -RuleName 'Allow-Lab-Subnet' -Priority 100 -Protocol '*' -SourceAddressPrefix @($SubnetPrefix) -DestinationPortRange @('*') -Description 'Permit east-west lab traffic inside the subnet.'
    Set-LabNsgRule -RuleName 'Allow-Executor-WindowsMgmt' -Priority 120 -Protocol 'Tcp' -SourceAddressPrefix @($executorCidr) -DestinationPortRange @('3389', '5985', '5986') -Description 'Permit RDP and WinRM from the executor IP only.'
    Set-LabNsgRule -RuleName 'Allow-Executor-Ssh' -Priority 130 -Protocol 'Tcp' -SourceAddressPrefix @($executorCidr) -DestinationPortRange @('22') -Description 'Permit SSH from the executor IP only.'
}

if ($PSCmdlet.ShouldProcess($SubnetName, 'Associate subnet with the lab NSG')) {
    Invoke-LabAzCli -Arguments @(
        'network', 'vnet', 'subnet', 'update',
        '--resource-group', $ResourceGroupName,
        '--vnet-name', $VNetName,
        '--name', $SubnetName,
        '--address-prefixes', $SubnetPrefix,
        '--network-security-group', $NsgName,
        '--output', 'none'
    ) | Out-Null
}

[PSCustomObject]@{
    ResourceGroupName = $ResourceGroupName
    VNetName          = $VNetName
    AddressPrefix     = $AddressPrefix
    SubnetName        = $SubnetName
    SubnetPrefix      = $SubnetPrefix
    NsgName           = $NsgName
    ExecutorPublicIp  = $executorCidr
    DnsServer         = $DnsServer
}
