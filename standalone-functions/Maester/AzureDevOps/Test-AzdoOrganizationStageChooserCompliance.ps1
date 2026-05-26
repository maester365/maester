function Test-AzdoOrganizationStageChooserCompliance {
    <#
    .SYNOPSIS
    Returns a boolean depending on the configuration.

    .DESCRIPTION
    Checks the status if users are able to choose what stages to run or skip.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml
    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-AzdoOrganizationStageChooserCompliance
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
    try {
        $azContext = Get-AzContext
        if ($null -eq $azContext) {
            Write-Verbose "Not connected to Azure"
            return $null
        }
    } catch {
        Write-Verbose "Azure connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose "Running Test-AzdoOrganizationStageChooser"


    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        return $null
    }

    $result = $settings.disableStageChooser

    if (-not $result) {
        $resultMarkdown = "Users are able to select stages to skip from the Queue Pipeline panel."
    } else {
        $resultMarkdown = "Users will not be able to select stages to skip from the Queue Pipeline panel."
    }


    return -not $result

}
