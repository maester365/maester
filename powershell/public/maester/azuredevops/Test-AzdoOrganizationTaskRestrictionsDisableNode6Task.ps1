<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status if Node 6 is allowed on hosted agents.

    https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview?view=azure-devops#prevent-malicious-code-execution
    https://learn.microsoft.com/en-us/azure/devops/release-notes/roadmap/2022/no-node-6-on-hosted-agents

.EXAMPLE
    ```
    Test-AzdoOrganizationTaskRestrictionsDisableNode6Task
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationTaskRestrictionsDisableNode6Task
#>
function Test-AzdoOrganizationTaskRestrictionsDisableNode6Task {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoOrganizationTaskRestrictionsDisableNode6Task"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $settings = Get-ADOPSOrganizationPipelineSettings

    if ($settings -eq 'AccessDeniedException') {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Insufficient permissions to access the pipeline settings API. Please ensure you have the necessary permissions to access this information.'
        return $null
    }

    $result = $settings.disableNode6TasksVar

    if ($result) {
        $resultMarkdown = "Pipelines will fail if they utilize a task with a Node 6 execution handler."
    } else {
        $resultMarkdown = "Pipelines may utilize a task with Node 6 execution handler."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
