<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if leaked Personal Access Token auto-revocation is enabled.

    Requires Azure DevOps organization backed by a Microsoft Entra tenant and
    Azure DevOps Administrator permissions.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens


.EXAMPLE
    ```
    Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation
#>

function Test-AzdoEnableLeakedPersonalAccessTokenAutoRevocation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Policy = Get-ADOPSTenantPolicy -PolicyCategory EnableLeakedPersonalAccessTokenAutoRevocation -Force

    if ($null -eq $Policy) {
        $Message = "Tenant Policy for EnableLeakedPersonalAccessTokenAutoRevocation not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
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