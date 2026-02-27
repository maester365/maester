<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of Third-party application access via OAuth.

    https://aka.ms/vstspolicyoauth
    https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/azure-devops-oauth?view=azure-devops


.EXAMPLE
    ```
    Test-AzdoThirdPartyAccessViaOauth
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoThirdPartyAccessViaOauth
#>
function Test-AzdoThirdPartyAccessViaOauth {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection' -Force
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowOAuthAuthentication'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    } else {
        $resultMarkdown = "Your tenant have not restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}