<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of when you sign in to the web portal of a Microsoft Entra ID-backed organization,
    Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-conditional-access?view=azure-devops&tabs=preview-page

.EXAMPLE
    ```
    Test-AzdoEnforceAADConditionalAccess
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoEnforceAADConditionalAccess
#>
function Test-AzdoEnforceAADConditionalAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoEnforceAADConditionalAccess"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.EnforceAADConditionalAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators."
    } else {
        $resultMarkdown = "Your tenant should always perform validation for any Conditional Access Policies (CAPs) set by tenant administrators. "
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}