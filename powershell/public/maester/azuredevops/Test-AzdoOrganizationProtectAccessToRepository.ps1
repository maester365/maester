<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if checks and approvals are applied when accessing repositories from YAML pipelines.
    Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#restrict-project-repository-and-service-connection-access

.EXAMPLE
    ```
    Test-AzdoOrganizationProtectAccessToRepository
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationProtectAccessToRepository
#>
function Test-AzdoOrganizationProtectAccessToRepository {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationProtectAccessToRepository"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Insufficient permissions to access the pipeline settings API. Please ensure you have the necessary permissions to access this information.'
        return $null
    }

    $result = $settings.enforceReferencedRepoScopedToken

    if ($result) {
        $resultMarkdown = "Checks and approvals are applied when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline."
    } else {
        $resultMarkdown = "Checks and approvals are not applied when accessing repositories from YAML pipelines. Also, a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline is not generated."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
