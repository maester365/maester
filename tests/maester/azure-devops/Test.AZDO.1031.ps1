<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if SSH key expiration validation is configured.

    https://learn.microsoft.com/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#ssh-key-policies

.EXAMPLE
    ```
    Test-AzdoValidateSshKeyExpiration
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoValidateSshKeyExpiration
#>

function Test-AzdoValidateSshKeyExpiration {
    [MaesterTest(
        Id = 'AZDO.1031',
        Title = 'Validate SSH Key Expiration.',
        Severity = 'High',
        Category = 'Azure DevOps',
        Product = 'Azure DevOps',
        Tag = 'AZDO',
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://learn.microsoft.com/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#ssh-key-policies'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoValidateSshKeyExpiration"

$SecurityPolicies = Get-ADOPSOrganizationPolicy -Force
    $Policy = $SecurityPolicies | where-object -property name -eq 'Policy.ValidateSshKeyExpiration'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant has SSH key expiration validation enabled."
    } else {
        $resultMarkdown = "Your tenant does not have SSH key expiration validation enabled."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
