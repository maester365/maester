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
<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of when you sign in to the web portal of a Microsoft Entra ID-backed organization,
    Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators.

    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/auditing-streaming?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoExternalGuestAccess
    ```

    Returns a boolean depending on the configuration.
    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw
.LINK
#>
function Test-AzdoOrganizationTaskRestrictionsDisableNode6Task {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

Write-verbose 'Not connected to Azure DevOps'

    $result = (Get-ADOPSOrganizationPipelineSettings).disableNode6TasksVar

    if ($result) {
        $resultMarkdown = "Well done. Pipelines will fail if they utilize a task with a Node 6 execution handler."
    }
    else {
        $resultMarkdown = "Pipeliens may utilize a task with Node 6 execution handler."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
