function Test-AzdoLogAuditEvents {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.LogAuditEvents'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has auditing enabled, tracking events such as permission changes, deleted resources, log access and downloads with many other types of changes."
    }
    else {
        $resultMarkdown = "Your tenant do not have logging enabled for Azure DevOps"
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'Critical'

    return $result
}