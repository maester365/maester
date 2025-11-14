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

# MT.1101 - Default Branding Profile should be customized
function Test-MtTenantCustomization{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Apple Volume Purchase Program Token for Intune...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }


    try {
        $brandingProfiles = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/intuneBrandingProfiles' -ApiVersion beta)
        $defaultProfile = $brandingProfiles | Where-Object {$_.isDefaultProfile}

        # displayName is reflected as 'Organization name' in the portal
        $defaultProfileIsCustomized = -not ([string]::IsNullOrEmpty($defaultProfile.displayName) -or [string]::IsNullOrEmpty($defaultProfile.privacyUrl))

        return $defaultProfileIsCustomized -or $brandingProfiles.Count -gt 1
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
