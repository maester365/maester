<#
.SYNOPSIS
    Ensure the built-in Device Compliance Policy markes devices with no compliance policy assigned as 'Not compliant'

.DESCRIPTION
    The built-in Device Compliance Policy should mark devices with no compliance policy assigned as 'Not compliant'


.EXAMPLE
    Test-MtDeviceComplianceSettings

    Returns true if the device compliance settings are configured

.LINK
    https://maester.dev/docs/commands/Test-MtDeviceComplianceSettings
#>
function Test-MtDeviceComplianceSettings {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ((Get-MtLicenseInformation EntraID) -eq "Free") {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    $scopes = (Get-MgContext).Scopes
    $permissionMissing = "DeviceManagementManagedDevices.Read.All" -notin $scopes
    if($permissionMissing){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Missing Scope 'DeviceManagementManagedDevices.Read.All'"
        return $null
    }

    $return = $true
    try {
        $deviceComplianceSettings = Invoke-MtGraphRequest -RelativeUri "deviceManagement/settings" -ApiVersion beta
        if ($deviceComplianceSettings.secureByDefault -ne $true) {
            $testResultMarkdown = "Your Intune built-in Device Compliance Policy markes devices with no compliance policy assigned as 'Compliant'."
            $return = $false
        } else {
            $testResultMarkdown = "Well done. Your Intune built-in Device Compliance Policy markes devices with no compliance policy assigned as 'Not compliant'."
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
    } catch {
        $return = $false
        Write-Error $_.Exception.Message
    }
    return $return
}