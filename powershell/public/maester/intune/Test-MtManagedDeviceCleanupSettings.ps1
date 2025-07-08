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
        $deviceCleanupSettings = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/managedDeviceCleanupSettings' -ApiVersion beta
        if ((-not $deviceCleanupSettings.deviceInactivityBeforeRetirementInDays) -or ($deviceCleanupSettings.deviceInactivityBeforeRetirementInDays -eq 0)) {
            $testResultMarkdown = 'Your Intune device clean-up rule is not configured.'
            $return = $false
        } else {
            $testResultMarkdown = "Well done. Your Intune device clean-up rule is configured to retire inactive devices after $($deviceCleanupSettings.deviceInactivityBeforeRetirementInDays) days."
            $return = $true
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
