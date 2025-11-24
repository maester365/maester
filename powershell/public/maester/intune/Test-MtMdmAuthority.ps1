<#
.SYNOPSIS
    Check the MDM Authority for Intune.
.DESCRIPTION
    This command checks the Mobile Device Management (MDM) Authority setting in Microsoft Intune to determine if Intune is the configured MDM authority.

.EXAMPLE
    Test-MtMdmAuthority

    Returns true if Intune is set as the MDM authority, false otherwise.

.LINK
    https://maester.dev/docs/commands/Test-MtMdmAuthority
#>
function Test-MtMdmAuthority {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing MDM Authority...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving MDM Authority status...'
        $org = Invoke-MtGraphRequest -RelativeUri 'organization' -ApiVersion beta
        $detailedOrgInfo = Invoke-MtGraphRequest -RelativeUri "organization/$($org.id)?`$select=mobiledevicemanagementauthority" -ApiVersion beta
        Add-MtTestResultDetail -Result ('MDM Authority is set to: {0}' -f $detailedOrgInfo.mobileDeviceManagementAuthority)
        return $detailedOrgInfo.mobileDeviceManagementAuthority -eq 'intune'
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
