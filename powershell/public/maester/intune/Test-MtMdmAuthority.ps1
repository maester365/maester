<#
.SYNOPSIS
    Check the Intune Diagnostic Settings for Audit Logs.
.DESCRIPTION
    Enumarate all diagnostic settings for Intune and check if Audit Logs are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.EXAMPLE
    Test-MtMobileThreatDefenseConnectors

    Returns true if any Intune diagnostic settings include Audit Logs and are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.LINK
    https://maester.dev/docs/commands/Test-MtMobileThreatDefenseConnectors
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
        $org = Invoke-MtGraphRequest -RelativeUri 'organization' -ApiVersion beta
        $detailedOrgInfo = Invoke-MtGraphRequest -RelativeUri "organization/$($org.id)?`$select=mobiledevicemanagementauthority" -ApiVersion beta
        Add-MtTestResultDetail -Result ('MDM Authority is set to: {0}' -f $detailedOrgInfo.mobileDeviceManagementAuthority)
        return $detailedOrgInfo.mobileDeviceManagementAuthority -eq 'intune'
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
