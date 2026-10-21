<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if leaked Personal Access Token auto-revocation is enabled.

    Requires Azure DevOps organization backed by a Microsoft Entra tenant and
    Azure DevOps Administrator permissions.

    Requires Azure DevOps to be connected with a user account. The test is skipped when connected
    as a service principal or managed identity.

    https://learn.microsoft.com/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens

.EXAMPLE
    ```
    Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation
#>

function Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation {
    [MaesterTest(
        Id = 'AZDO.1033',
        Title = '(Tenant) Enable automatic revocation of leaked Personal Access Tokens.',
        Product = 'azure-devops',
        Feature = 'security-policies',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1552.001', 'T1593.003', 'T1550.001'),
        Control = 'nist-800-53-r5:IA-5',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation"

    if ((Get-MtAzdoIdentityType) -eq 'ServicePrincipal') {
        Add-MtTestResultDetail -SkippedBecause NotSupportedAzureDevOpsAppPermission
    }

$Policy = Get-ADOPSTenantPolicy -PolicyCategory EnableLeakedPersonalAccessTokenAutoRevocation -Force

    if ($null -eq $Policy) {
        $Message = "Tenant Policy for EnableLeakedPersonalAccessTokenAutoRevocation not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
    }
    else {
        $result = [bool]$Policy.value
        if ($result) {
            $resultMarkdown = "Your tenant has leaked Personal Access Token auto-revocation enabled."
        }
        else {
            $resultMarkdown = "Your tenant does not have leaked Personal Access Token auto-revocation enabled."
        }

        Add-MtTestResultDetail -Result $resultMarkdown

        return $result
    }
}
