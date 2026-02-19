<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if auditing of events is configured.

    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/azure-devops-auditing?view=azure-devops&tabs=preview-page#enable-and-disable-auditing
    https://learn.microsoft.com/en-us/azure/devops/organizations/audit/azure-devops-auditing?view=azure-devops&tabs=preview-page#review-audit-log


.EXAMPLE
    ```
    Test-AzdoLogAuditEvent
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoLogAuditEvent
#>

function Test-AzdoLogAuditEvent {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

Write-verbose 'Not connected to Azure DevOps'

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.LogAuditEvents'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has auditing enabled, tracking events such as permission changes, deleted resources, log access and downloads with many other types of changes."
    }
    else {
        $resultMarkdown = "Your tenant do not have logging enabled for Azure DevOps"
    }



    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}