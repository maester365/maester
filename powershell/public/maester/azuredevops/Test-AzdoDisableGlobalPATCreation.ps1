<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if global Personal Access Token creation is restricted.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy


.EXAMPLE
    ```
    Test-AzdoDisableGlobalPATCreation
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoDisableGlobalPATCreation
#>

function Test-AzdoDisableGlobalPATCreation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
        break
    }

    $Policy = Get-ADOPSTenantPolicy -PolicyCategory RestrictGlobalPersonalAccessToken
    $result = [bool]$Policy.value
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has Global Personal Access Token creation disabled."
    } else {
        $resultMarkdown = "Your tenant does not have Global Personal Access Token creation disabled."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}