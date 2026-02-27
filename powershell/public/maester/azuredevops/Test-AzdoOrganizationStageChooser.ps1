<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if users are able to choose what stages to run or skip.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml
    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoOrganizationStageChooser
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationStageChooser
#>
function Test-AzdoOrganizationStageChooser {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableStageChooser

    if (-not $result) {
        $resultMarkdown = "Users are able to select stages to skip from the Queue Pipeline panel."
    } else {
        $resultMarkdown = "Well done. Users will not be able to select stages to skip from the Queue Pipeline panel."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return -not $result
}
