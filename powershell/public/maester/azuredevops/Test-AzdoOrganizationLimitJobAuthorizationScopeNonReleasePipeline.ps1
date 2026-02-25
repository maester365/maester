<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks IF YAML & build pipelines have restricted access to only those repositories that are in the same project as the pipeline.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope

.EXAMPLE
    ```
    Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline
#>
function Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceJobAuthScope

    if ($result) {
        $resultMarkdown = "Well done. Access tokens have reduced scope of access for all non-release pipelines."
    } else {
        $resultMarkdown = "Non-Release Pipelines can run with collection scoped access tokens"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
