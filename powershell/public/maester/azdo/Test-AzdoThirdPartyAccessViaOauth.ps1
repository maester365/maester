function Test-AzdoThirdPartyAccessViaOauth {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection'
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowOAuthAuthentication'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant have not restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    }
    else {
        $resultMarkdown = "Well done. Your tenant has restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    }

    # $Description = Get-Content $PSScriptRoot\$($MyInvocation.MyCommand.Name).md -Raw

    Add-MtTestResultDetail -Result $resultMarkdown  -Severity 'High'

    return $result
}