function Test-MtTenantCustomizationCompliance {
    <#
    .SYNOPSIS
    Check the Intune Tenant Customization.

    .DESCRIPTION
    This command checks the Intune Tenant Customization settings, specifically the Default Branding Profile, to determine if it has been customized.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtTenantCustomizationCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation

    try {
        Write-Verbose 'Retrieving Intune Branding Profiles status...'
        $brandingProfiles = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/intuneBrandingProfiles'
        $defaultProfile = $brandingProfiles | Where-Object { $_.isDefaultProfile }

        # displayName is reflected as 'Organization name' in the portal
        $defaultProfileIsCustomized = -not ([string]::IsNullOrEmpty($defaultProfile.displayName) -and [string]::IsNullOrEmpty($defaultProfile.privacyUrl))

        if ($defaultProfileIsCustomized) {

            if (-not [string]::IsNullOrEmpty($defaultProfile.displayName)) {
            }
        } else {
        }

        return $defaultProfileIsCustomized -or $brandingProfiles.Count -gt 1
    } catch {
        return $null
    }

}
