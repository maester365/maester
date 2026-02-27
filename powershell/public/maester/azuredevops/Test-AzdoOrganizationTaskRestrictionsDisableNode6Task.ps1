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

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $result = (Get-ADOPSOrganizationPipelineSettings).disableNode6TasksVar

    if ($result) {
        $resultMarkdown = "Well done. Pipelines will fail if they utilize a task with a Node 6 execution handler."
    } else {
        $resultMarkdown = "Pipelines may utilize a task with Node 6 execution handler."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
