<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if organization creation is restricted.

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

    $Policy = Get-ADOPSTenantPolicy -PolicyCategory OrganizationCreationRestriction
    $result = [bool]$Policy.value
    if ($result) {
        $resultMarkdown = "Well done. Your tenant has organization creation restricted."
    } else {
        $resultMarkdown = "Your tenant does not have organization creation restricted."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}