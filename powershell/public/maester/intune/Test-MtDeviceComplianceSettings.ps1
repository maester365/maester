<#
.SYNOPSIS
    Ensure the built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple settings.')]
    param()

    if ((Get-MtLicenseInformation EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $deviceComplianceSettings = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/settings' -ApiVersion beta
        Write-Verbose "Device Compliance Settings: $deviceComplianceSettings"
        if ($deviceComplianceSettings.secureByDefault -ne $true) {
            $testResultMarkdown = "Your Intune built-in Device Compliance Policy **incorrectly** marks devices with no compliance policy assigned as 'Compliant'."
            $return = $false
        } else {
            $testResultMarkdown = "Well done. Your Intune built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'."
            $return = $true
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
