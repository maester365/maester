<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks IF YAML & build pipelines have restricted access to only those repositories that are in the same project as the pipeline.

    https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope

.EXAMPLE
    ```
    Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline
#>
function Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline {
    [MaesterTest(
        Id = 'AZDO.1016',
        Title = 'Limit job authorization scope to current project for non-release pipelines.',
        Severity = 'High',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationLimitJobAuthorizationScopeNonReleasePipeline"

$settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Insufficient permissions to access the pipeline settings API. Please ensure you have the necessary permissions to access this information.'
        return $null
    }

    $result = $settings.enforceJobAuthScope

    if ($result) {
        $resultMarkdown = "Access tokens have reduced scope of access for all non-release pipelines."
    } else {
        $resultMarkdown = "Non-Release Pipelines can run with collection scoped access tokens"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
