<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if release pipelines have restricted access to only those repositories that are in the same project as the pipeline.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/process/access-tokens?view=azure-devops&tabs=yaml#job-authorization-scope

.EXAMPLE
    ```
    Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipeline
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipeline
#>
function Test-AzdoOrganizationLimitJobAuthorizationScopeReleasePipeline {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Insufficient permissions to access the pipeline settings API. Please ensure you have the necessary permissions to access this information.'
        return $null
    }

    $result = $settings.enforceJobAuthScopeForReleases

    if ($result) {
        $resultMarkdown = "Access tokens have reduced scope of access for all classic release pipelines."
    } else {
        $resultMarkdown = "Classic Release Pipelines can run with collection scoped access tokens"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
