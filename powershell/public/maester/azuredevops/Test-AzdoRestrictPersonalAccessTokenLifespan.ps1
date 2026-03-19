<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if Personal Access Token lifespan restrictions are configured.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-personal-access-token-lifespan


.EXAMPLE
    ```
    Test-AzdoRestrictPersonalAccessTokenLifespan
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoRestrictPersonalAccessTokenLifespan
#>

function Test-AzdoRestrictPersonalAccessTokenLifespan {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Policy = Get-ADOPSTenantPolicy -PolicyCategory RestrictPersonalAccessTokenLifespan -Force
    if ($null -eq $Policy) {
        $Message = "Tenant Policy for RestrictPersonalAccessTokenLifespan not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
    }
    else {
        $result = [bool]$Policy.value
        if ($result) {
            $MaxPatLifespanInDays = $Policy.properties.MaxPatLifespanInDays
            if ($MaxPatLifespanInDays -gt 0) {
                $resultMarkdown = "Your tenant has Personal Access Token lifespan restrictions enabled with a maximum lifespan of $MaxPatLifespanInDays days."
            }
            else {
                $resultMarkdown = "Your tenant has Personal Access Token lifespan restrictions enabled."
            }
        }
        else {
            $resultMarkdown = "Your tenant does not have Personal Access Token lifespan restrictions enabled."
        }
    
        Add-MtTestResultDetail -Result $resultMarkdown
    
        return $result
    }
}