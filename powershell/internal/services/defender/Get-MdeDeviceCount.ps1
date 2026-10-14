function Get-MdeDeviceCount {
    <#
    .SYNOPSIS
        Counts how many devices are protected by Microsoft Defender for Endpoint

    .DESCRIPTION
        Returns the number of Windows devices that can receive MDE antivirus policies.
        Only includes devices managed by Defender ('msSense') or Intune ('mdm').

    .PARAMETER IncludeDetails
        Returns detailed device information instead of just the count

    .EXAMPLE
        Get-MdeDeviceCount

        Returns the number of MDE-protected devices.

    .EXAMPLE
        Get-MdeDeviceCount -IncludeDetails

        Returns a hashtable with Count, Devices, and TotalManagedDevices.

    #>
    [CmdletBinding(DefaultParameterSetName = 'Count')]
    [OutputType([int], ParameterSetName = 'Count')]
    [OutputType([hashtable], ParameterSetName = 'Details')]
    param(
        [Parameter(ParameterSetName = 'Details')]
        [switch]$IncludeDetails
    )

    try {
        $mdeConfig = Get-MdeConfiguration -ErrorAction SilentlyContinue

        $mdeDevices = @()
        $mdeDeviceCount = 0

        if ($mdeConfig -and $mdeConfig.ManagedDevices) {
            $mdeDevices = @($mdeConfig.ManagedDevices | Where-Object {
                $_.managementAgent -in @('msSense', 'mdm') -and
                $_.operatingSystem -eq 'Windows'
            })
            $mdeDeviceCount = $mdeDevices.Count
        }

        Write-Verbose "Found $mdeDeviceCount Windows devices eligible for MDE antivirus policy testing"

        if ($IncludeDetails) {
            return @{
                Count               = $mdeDeviceCount
                Devices             = $mdeDevices
                TotalManagedDevices = if ($mdeConfig.ManagedDevices) { $mdeConfig.ManagedDevices.Count } else { 0 }
            }
        } else {
            return $mdeDeviceCount
        }

    } catch {
        Write-Verbose "Error getting MDE device count: $($_.Exception.Message)"

        if ($IncludeDetails) {
            return @{
                Count               = 0
                Devices             = @()
                TotalManagedDevices = 0
                Error               = "Error: $($_.Exception.Message)"
            }
        } else {
            return 0
        }
    }
}
