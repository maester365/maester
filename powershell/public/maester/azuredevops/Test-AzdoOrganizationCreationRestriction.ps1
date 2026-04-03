<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if organization creation is restricted.

    Requires Azure DevOps organization backed by a Microsoft Entra tenant and
    Azure DevOps Administrator permissions.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/azure-ad-tenant-policy-restrict-org-creation?view=azure-devops#turn-on-the-policy


.EXAMPLE
    ```
    Test-AzdoOrganizationCreationRestriction
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationCreationRestriction
#>

function Test-AzdoOrganizationCreationRestriction {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $Policy = Get-ADOPSTenantPolicy -PolicyCategory OrganizationCreationRestriction -Force
    $result = [bool]$Policy.value
    if ($null -eq $Policy) {
        $Message = "Tenant Policy for OrganizationCreationRestriction not found. This may be due to insufficient permissions or the Azure DevOps Organization is not backed by an Entra ID tenant.
        Please see [Manage Tenant Policies](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#prerequisites)"
        Write-Verbose $Message
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $Message
    }
    else {
        if ($result) {
            $resultMarkdown = "Your tenant has organization creation restricted."
        }
        else {
            $resultMarkdown = "Your tenant does not have organization creation restricted."
        }
    
        Add-MtTestResultDetail -Result $resultMarkdown
    
        return $result
    }
}