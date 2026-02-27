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

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).enforceReferencedRepoScopedToken

    if ($result) {
        $resultMarkdown = "Checks and approvals are applied when accessing repositories from YAML pipelines. Also, generate a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline."
    } else {
        $resultMarkdown = "Checks and approvals are not applied when accessing repositories from YAML pipelines. Also, a job access token that is scoped to repositories that are explicitly referenced in the YAML pipeline is not generated."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
