<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of public projects within your Azure DevOps Organization.

    https://aka.ms/vsts-anon-access
    https://learn.microsoft.com/en-us/azure/devops/organizations/projects/make-project-public?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoPublicProject
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoPublicProject
#>
function Test-AzdoPublicProject {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security'
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.AllowAnonymousAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your Azure DevOps tenant allows the creation and use of public projects"
    } else {
        $resultMarkdown = "Well done. Your tenant has disabled the use of public projects"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}