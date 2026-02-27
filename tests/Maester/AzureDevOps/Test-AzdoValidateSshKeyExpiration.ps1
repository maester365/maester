<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if SSH key expiration validation is configured.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/change-application-access-policies?view=azure-devops#ssh-key-policies


.EXAMPLE
    ```
    Test-AzdoValidateSshKeyExpiration
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoValidateSshKeyExpiration
#>

function Test-AzdoValidateSshKeyExpiration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -Force
    $Policy = $SecurityPolicies | where-object -property name -eq 'Policy.ValidateSshKeyExpiration'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "Your tenant has SSH key expiration validation enabled."
    } else {
        $resultMarkdown = "Your tenant does not have SSH key expiration validation enabled."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}