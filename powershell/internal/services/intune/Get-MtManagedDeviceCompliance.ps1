function Get-MtManagedDeviceCompliance {
    <#
    .SYNOPSIS
    Retrieves Intune managed devices with the compliance state Intune reports for each.

    .DESCRIPTION
    Queries Intune managed devices and returns a normalized object per device carrying the display name,
    operating system and the compliance state Intune last evaluated. The caller buckets those states to
    measure how many devices are non-compliant.

    Returns $null when the managed devices could not be read at all, so that callers can report a skip
    rather than a failure. The populated result is emitted with -NoEnumerate because PowerShell unrolls
    collections on output: an empty list would otherwise arrive at the caller as $null and be
    indistinguishable from a read failure. This matters because Invoke-MtGraphRequest surfaces a failed
    call as a non-terminating error with a null result, which collects as a single empty element.
    Treating that as "no devices exist" would produce a false negative: a device-compliance result
    reported purely because the signed-in account lacked permission.

    The compliance state is lower-cased on the way out. The complianceState enum is documented in lower
    case, but Graph has returned mixed casing in the past, and the caller decides pass or fail on an exact
    match against the state, so normalising it here keeps that decision correct.

    Errors are deliberately not caught here. The calling check guards only this retrieval, maps 401/403
    to NotAuthorized and rethrows anything else, so swallowing the exception at this level would lose the
    status code and turn a permission problem into a false result.

    .EXAMPLE
    Get-MtManagedDeviceCompliance

    Returns the Intune managed devices configured in the tenant with their compliance state.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[pscustomobject]])]
    param()

    $devices = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/managedDevices' `
            -Select 'id', 'deviceName', 'operatingSystem', 'complianceState' -ErrorAction Stop)

    # A failed request yields elements with no id. Distinguish that from a tenant with no enrolled devices.
    $usable = @($devices | Where-Object { $_ -and $_.id })
    if ($devices.Count -gt 0 -and $usable.Count -eq 0) {
        Write-Verbose "Managed devices could not be read; returning null so the caller reports a skip."
        return $null
    }

    $result = [System.Collections.Generic.List[pscustomobject]]::new()
    foreach ($device in $usable) {
        $result.Add([pscustomobject]@{
                Id              = $device.id
                Name            = $device.deviceName
                OperatingSystem = $device.operatingSystem
                ComplianceState = ([string]$device.complianceState).ToLowerInvariant()
            })
    }

    # -NoEnumerate keeps an empty list from collapsing to $null.
    Write-Output $result -NoEnumerate
}
