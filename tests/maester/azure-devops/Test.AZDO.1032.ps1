<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if global Personal Access Token creation is restricted.

    Requires Azure DevOps organization backed by a Microsoft Entra tenant and
    Azure DevOps Administrator permissions.

    https://learn.microsoft.com/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy

.EXAMPLE
    ```
    Test-AzdoDisableGlobalPATCreation
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoDisableGlobalPATCreation
#>

function Test-AzdoDisableGlobalPATCreation {
    [MaesterTest(
        Id = 'AZDO.1032',
        Title = '(Tenant) Restrict creation of global Personal Access Tokens.',
        Severity = 'High',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoDisableGlobalPATCreation"

$Policy = Get-ADOPSTenantPolicy -PolicyCategory RestrictGlobalPersonalAccessToken -Force

    if ($null -eq $Policy) {
        $Message = "Tenant Policy for RestrictGlobalPersonalAccessToken not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
    }
    else {
        $result = [bool]$Policy.value
        if ($result) {
            $resultMarkdown = "Your tenant has Global Personal Access Token creation disabled."
        }
        else {
            $resultMarkdown = "Your tenant does not have Global Personal Access Token creation disabled."
        }

        Add-MtTestResultDetail -Result $resultMarkdown
        return $result
    }

}
