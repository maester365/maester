<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if extensions are allowed to access resources on the local network.

    https://learn.microsoft.com/en-us/azure/devops/marketplace/allow-extensions-local-network?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoAllowExtensionsLocalNetworkAccess
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoAllowExtensionsLocalNetworkAccess
#>
function Test-AzdoAllowExtensionsLocalNetworkAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Running Test-AzdoAllowExtensionsLocalNetworkAccess"

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.AllowExtensionsLocalNetworkAccess'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your organization allows extensions to access resources on the local network."
    } else {
        $resultMarkdown = "Your organization does not allow extensions to access resources on the local network."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
