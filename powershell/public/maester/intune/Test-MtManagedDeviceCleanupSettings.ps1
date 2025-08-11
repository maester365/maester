<#
.SYNOPSIS
    Ensure device clean-up rule is configured

.DESCRIPTION
    The device clean-up rule should be configured

.EXAMPLE
    Test-MtManagedDeviceCleanupSettings

    Returns true if the device clean-up rule is configured

.LINK
    https://maester.dev/docs/commands/Test-MtManagedDeviceCleanupSettings
#>
function Test-MtManagedDeviceCleanupSettings {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test refers to multiple settings.')]
    param()

    Write-Verbose 'Testing device clean-up rule configuration'
    if ((Get-MtLicenseInformation EntraID) -eq 'Free') {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    try {
        $deviceCleanupSettings = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/managedDeviceCleanupRules' -ApiVersion beta
        if ((-not $deviceCleanupSettings.deviceInactivityBeforeRetirementInDays) -or ($deviceCleanupSettings.deviceInactivityBeforeRetirementInDays -eq 0)) {
            $testResultMarkdown = 'No Intune device clean-up rule is configured.'
            $return = $false
        } else {
            $testResultMarkdown = "Well done. At least one Intune device clean-up rule is configured.`n"
            $testResultMarkdown += "| Name | Platfrom | Days to retire |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"
            foreach ($setting in $deviceCleanupSettings) {
                $testResultMarkdown += "| $($setting.displayName) | $($setting.deviceCleanupRulePlatformType) | $($setting.deviceInactivityBeforeRetirementInDays) |`n"
            }
            $return = $true
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
