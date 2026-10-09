function Test-MtWindowsDataProcessor {
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
    [MaesterTest(
        Id = 'MT.1099',
        Title = 'Windows Diagnostic Data Processing should be enabled',
        Severity = 'Low',
        Category = 'Maester/Intune',
        Tag = ('Intune', 'Maester'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'nicolonsky'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Retrieving Windows Data Processor status...'
    $dataProcessor = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/dataProcessorServiceForWindowsFeaturesOnboarding' -ApiVersion beta
    $testResultMarkdown = "Windows data processor status:`n"
    $testResultMarkdown += "* Enable features that require Windows diagnostic data in processor configuration: {0} `n" -f $dataProcessor.areDataProcessorServiceForWindowsFeaturesEnabled
    $testResultMarkdown += "* Windows license verification status: {0} `n" -f $dataProcessor.hasValidWindowsLicense
    Add-MtTestResultDetail -Result $testResultMarkdown
    return ($dataProcessor.hasValidWindowsLicense -and $dataProcessor.areDataProcessorServiceForWindowsFeaturesEnabled)
}
