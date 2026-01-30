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

    Write-verbose 'Not connected to Azure DevOps'

    $ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection'
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowOAuthAuthentication'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant have not restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    } else {
        $resultMarkdown = "Well done. Your tenant has restricted Azure DevOps OAuth apps to access resources in your organization through OAuth."
    }



    Add-MtTestResultDetail -Result $resultMarkdown -Severity 'High'

    return $result
}