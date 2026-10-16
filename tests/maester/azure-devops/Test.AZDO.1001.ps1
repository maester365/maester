<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of the possibility to use SSH keys to connect to Azure DevOps.

    https://aka.ms/vstspolicyssh
    https://learn.microsoft.com/azure/devops/repos/git/auth-overview?view=azure-devops&source=recommendations&tabs=Windows

.EXAMPLE
    ```
    Test-AzdoSSHAuthentication
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoSSHAuthentication
#>
function Test-AzdoSSHAuthentication {
    [MaesterTest(
        Id = 'AZDO.1001',
        Title = 'Identities can connect to your organization''s Git repos through SSH.',
        Product = 'azure-devops',
        Feature = 'security-policies',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1552.004', 'T1098.001'),
        Service = 'AzureDevOps',
        Author = 'SebastianClaesson',
        HelpUrl = 'https://aka.ms/vstspolicyssh'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoSSHAuthentication"

$ApplicationPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'ApplicationConnection' -Force
    $Policy = $ApplicationPolicies.policy | where-object -property name -eq 'Policy.DisallowSecureShell'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your tenant does not allow developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    } else {
        $resultMarkdown = "Your tenant allows developers to connect to your Git repos through SSH on macOS, Linux, or Windows to connect with Azure DevOps"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
