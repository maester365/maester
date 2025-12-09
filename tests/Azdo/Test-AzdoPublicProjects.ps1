function Test-AzdoPublicProjects {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.AllowAnonymousAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant allows the creation and use of public projects"
    }
    else {
        $resultMarkdown = "Well done. Your tenant has disabled the use of public projects"
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'Critical'

    return $result
}