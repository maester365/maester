<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the ability to install and run tasks from the Marketplace, which gives you greater control over the code that executes in a pipeline.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution

.EXAMPLE
    ```
    Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTask
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTask
#>
function Test-AzdoOrganizationTaskRestrictionsDisableMarketplaceTask {
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

    $result = $settings.disableMarketplaceTasksVar

    if ($result) {
        $resultMarkdown = "The ability to install and run tasks from the Marketplace has been restricted."
    } else {
        $resultMarkdown = "It is allowed to install and run tasks from the Marketplace."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
