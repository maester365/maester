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

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableClassicReleasePipelineCreation

    if (-not $result) {
        $resultMarkdown = "Classic release pipelines, task groups, and deployment groups can be created / imported."
    } else {
        $resultMarkdown = "No classic release pipelines, task groups, and deployment groups can be created / imported. Existing ones will continue to work."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return -not $result
}
