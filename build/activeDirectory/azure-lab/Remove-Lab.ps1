<#
.SYNOPSIS
    Removes Azure lab resources created by Deploy-Lab.ps1.

.DESCRIPTION
    Deletes the tagged VMs, NICs, public IPs, disks, Key Vaults, NSGs, and VNets
    associated with the Maester Azure AD E2E lab. The script is safe to rerun and
    skips resources that no longer exist.

.PARAMETER TagName
    Tag key used to discover lab resources.

.PARAMETER TagValue
    Tag value used to discover lab resources.

.EXAMPLE
    ./Remove-Lab.ps1 -TagName maester-lab-id -TagValue misoule-lab-20260818190000

    Removes all lab resources tagged with the supplied lab ID.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$TagName,

    [Parameter(Mandatory)]
    [string]$TagValue
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

function Get-LabResourcesByType {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourceType
    )

    $query = "[?resourceGroup=='$ResourceGroupName' && type=='$ResourceType'].id"
    $ids = Invoke-LabAzCli -Arguments @(
        'resource', 'list',
        '--tag', ('{0}={1}' -f $TagName, $TagValue),
        '--query', $query,
        '--output', 'tsv'
    )

    return [string[]]@($ids | Where-Object { $_ })
}

$resourceTypesInDeleteOrder = @(
    'Microsoft.Compute/virtualMachines',
    'Microsoft.Network/networkInterfaces',
    'Microsoft.Network/publicIPAddresses',
    'Microsoft.Compute/disks',
    'Microsoft.KeyVault/vaults',
    'Microsoft.Network/networkSecurityGroups',
    'Microsoft.Network/virtualNetworks'
)

$deletedResources = [System.Collections.Generic.List[string]]::new()

foreach ($resourceType in $resourceTypesInDeleteOrder) {
    foreach ($resourceId in (Get-LabResourcesByType -ResourceType $resourceType)) {
        if ($PSCmdlet.ShouldProcess($resourceId, 'Delete tagged Azure lab resource')) {
            Invoke-LabAzCli -Arguments @('resource', 'delete', '--ids', $resourceId, '--output', 'none') -AllowFailure | Out-Null
            $deletedResources.Add($resourceId)
        }
    }
}

[PSCustomObject]@{
    ResourceGroupName = $ResourceGroupName
    TagName           = $TagName
    TagValue          = $TagValue
    DeletedResources  = $deletedResources.ToArray()
}
