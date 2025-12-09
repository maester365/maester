<#
.SYNOPSIS
    Check the Intune Windows Data Processor settings.
.DESCRIPTION
    This command checks the Windows Data Processor settings in Microsoft Intune to determine if features requiring Windows diagnostic data are enabled and if the Windows license verification is complete.

.EXAMPLE
    Test-MtWindowsDataProcessor

    Returns true if features requiring Windows diagnostic data are enabled and the Windows license verification is complete.

.LINK
    https://maester.dev/docs/commands/Test-MtWindowsDataProcessor
#>
function Test-MtWindowsDataProcessor {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Windows Data Processor status...'
        $dataProcessor = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/dataProcessorServiceForWindowsFeaturesOnboarding' -ApiVersion beta
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
