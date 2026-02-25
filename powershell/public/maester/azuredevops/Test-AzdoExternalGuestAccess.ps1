<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the configuration of external guest access to Azure DevOps.

    https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops#manage-external-guest-access

.EXAMPLE
    ```
    Test-AzdoExternalGuestAccess
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoExternalGuestAccess
#>
function Test-AzdoExternalGuestAccess {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $PrivacyPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'User'
    $Policy = $PrivacyPolicies.policy | where-object -property name -eq 'Policy.DisallowAadGuestUserAccess'
    $result = $Policy.effectiveValue
    if ($result) {
        $resultMarkdown = "External user(s) can be added to the organization to which they were invited and has immediate access. A guest user can add other guest users to the organization after being granted the Guest Inviter role in Microsoft Entra ID."
    } else {
        $resultMarkdown = "Well done. External users should not be allowed access to your Azure DevOps organization"
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
