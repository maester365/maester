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

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.LogAuditEvents'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has auditing enabled, tracking events such as permission changes, deleted resources, log access and downloads with many other types of changes."
    } else {
        $resultMarkdown = "Your tenant does not have logging enabled for Azure DevOps"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}