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

Write-verbose 'Not connected to Azure DevOps'

    $result = (Get-ADOPSOrganizationPipelineSettings).disableStageChooser

    if (-not $result) {
        $resultMarkdown = "Users are able to select stages to skip from the Queue Pipeline panel."
    }
    else {
        $resultMarkdown = "Well done. Users will not be able to select stages to skip from the Queue Pipeline panel."
    }

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}
