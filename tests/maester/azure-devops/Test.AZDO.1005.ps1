<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of when you sign in to the web portal of a Microsoft Entra ID-backed organization,
    Microsoft Entra ID always performs validation for any Conditional Access Policies (CAPs) set by tenant administrators.

    https://learn.microsoft.com/azure/devops/organizations/accounts/manage-conditional-access?view=azure-devops&tabs=preview-page

.EXAMPLE
    ```
    Test-AzdoEnforceAADConditionalAccess
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoEnforceAADConditionalAccess
#>
function Test-AzdoEnforceAADConditionalAccess {
    [MaesterTest(
        Id = 'AZDO.1005',
        Title = 'IP Conditional Access policy validation.',
        Severity = 'High',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#cap-support-on-azure-devops'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoEnforceAADConditionalAccess"

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
