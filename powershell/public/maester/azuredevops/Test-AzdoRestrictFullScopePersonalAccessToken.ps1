<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if Personal Access Token full scope restrictions are configured.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-full-scope-personal-access-tokens


.EXAMPLE
    ```
    Test-AzdoRestrictFullScopePersonalAccessToken
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoRestrictFullScopePersonalAccessToken
#>

function Test-AzdoRestrictFullScopePersonalAccessToken {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Policy = Get-ADOPSTenantPolicy -PolicyCategory RestrictFullScopePersonalAccessToken -Force
    if ($null -eq $Policy) {
        $Message = "Tenant Policy for RestrictFullScopePersonalAccessToken not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
    }
    else {
        $result = [bool]$Policy.value
        if ($result) {
            $resultMarkdown = "Well done. Your tenant has Personal Access Token full scope restrictions enabled."
        }
        else {
            $resultMarkdown = "Your tenant does not have Personal Access Token full scope restrictions enabled."
        }
    
        Add-MtTestResultDetail -Result $resultMarkdown
    
        return $result
    }
}