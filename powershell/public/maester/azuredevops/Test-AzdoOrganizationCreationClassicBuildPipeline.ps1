<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if classic build pipelines can be created.

    https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines

.EXAMPLE
    ```
    Test-AzdoOrganizationCreationClassicBuildPipeline
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationCreationClassicBuildPipeline
#>

function Test-AzdoOrganizationCreationClassicBuildPipeline {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

Write-verbose 'Not connected to Azure DevOps'

    $PipelineCreation = (Get-ADOPSOrganizationPipelineSettings).disableClassicBuildPipelineCreation

    if ($PipelineCreation) {
        $resultMarkdown = "Well done. No classic build pipelines can be created / imported. Existing ones will continue to work."
        $result = $false
    }
    else {
        $resultMarkdown = "Classic build pipelines can be created / imported."
        $result = $true
    }



    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
