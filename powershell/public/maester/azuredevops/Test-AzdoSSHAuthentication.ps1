<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of the possibility to use SSH keys to connect to Azure DevOps.

    https://aka.ms/vstspolicyssh
    https://learn.microsoft.com/en-us/azure/devops/repos/git/auth-overview?view=azure-devops&source=recommendations&tabs=Windows

.EXAMPLE
    ```
    Test-AzdoSSHAuthentication
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoSSHAuthentication
#>
function Test-AzdoSSHAuthentication {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

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