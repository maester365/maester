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
function Test-MtWindowsDataProcessor{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Apple Volume Purchase Program Token for Intune...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }


    try {
        $dataProcessor = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/dataProcessorServiceForWindowsFeaturesOnboarding' -ApiVersion beta)

        $testResultMarkdown = "Windows data processor status:`n"
        $testResultMarkdown += "* Enable features that require Windows diagnostic data in processor configuration: {0} `n" -f $dataProcessor.areDataProcessorServiceForWindowsFeaturesEnabled
        $testResultMarkdown += "* Windows license verification status: {0} `n" -f $dataProcessor.hasValidWindowsLicense
        Add-MtTestResultDetail -Result $testResultMarkdown

        return ($dataProcessor.hasValidWindowsLicense -and $dataProcessor.areDataProcessorServiceForWindowsFeaturesEnabled)
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
