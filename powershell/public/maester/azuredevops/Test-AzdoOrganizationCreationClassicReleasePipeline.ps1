<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if classic release pipelines can be created.

    https://devblogs.microsoft.com/devops/disable-creation-of-classic-pipelines

.EXAMPLE
    ```
    Test-AzdoOrganizationCreationClassicReleasePipeline
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationCreationClassicReleasePipeline
#>
function Test-AzdoOrganizationCreationClassicReleasePipeline {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

Write-verbose 'Not connected to Azure DevOps'

    $PipelineCreation = (Get-ADOPSOrganizationPipelineSettings).disableClassicReleasePipelineCreation

    if ($PipelineCreation) {
        $resultMarkdown = "Well done. No classic release pipelines, task groups, and deployment groups can be created / imported. Existing ones will continue to work."
        $result = $false
    }
    else {
        $resultMarkdown = "Classic release pipelines, task groups, and deployment groups can be created / imported."
        $result = $true
    }



    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
