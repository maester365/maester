<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks if Personal Access Token creation is restricted at the organization level.

    https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoDisablePATCreation
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoDisablePATCreation
#>
function Test-AzdoDisablePATCreation {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection AzureDevOps)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzureDevOps
        return $null
    }

    $SecurityPolicies = Get-ADOPSOrganizationPolicy -PolicyCategory 'Security' -Force
    $Policy = $SecurityPolicies.policy | where-object -property name -eq 'Policy.DisablePATCreation'
    $result = $Policy.value
    if ($result) {
        $resultMarkdown = "Your organization has restricted Personal Access Token creation.`n`n"
        $resultMarkdown += "| Setting | Value |`n"
        $resultMarkdown += "| --- | --- |`n"
        $resultMarkdown += "| Allow list enabled | $($Policy.properties.isAllowListEnabled) |`n"
        $resultMarkdown += "| Packaging scope only | $($Policy.properties.isPackagingScopeEnabled) |`n"
        if ($Policy.properties.isAllowListEnabled -and $Policy.properties.allowedUsersAndGroupObjectIds.Count -gt 0) {
            $resultMarkdown += "`n| Display Name | Object ID |`n"
            $resultMarkdown += "| --- | --- |`n"
            $Policy.properties.allowedUsersAndGroupObjectIds | ForEach-Object {
                $resultMarkdown += "| $($_.displayName) | $($_.objectId) |`n"
            }
        }
    } else {
        $resultMarkdown = "Your organization has not restricted Personal Access Token creation."
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}
