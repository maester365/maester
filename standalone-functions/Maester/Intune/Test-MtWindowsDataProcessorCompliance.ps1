function Test-MtWindowsDataProcessorCompliance {
    <#
    .SYNOPSIS
    Check the Intune Windows Data Processor settings.

    .DESCRIPTION
    This command checks the Windows Data Processor settings in Microsoft Intune to determine if features requiring Windows diagnostic data are enabled and if the Windows license verification is complete.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtWindowsDataProcessorCompliance
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
        Write-Verbose 'Retrieving Windows Data Processor status...'
        $dataProcessor = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/dataProcessorServiceForWindowsFeaturesOnboarding'
        return ($dataProcessor.hasValidWindowsLicense -and $dataProcessor.areDataProcessorServiceForWindowsFeaturesEnabled)
    } catch {
        return $null
    }

}
