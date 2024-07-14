<#
.SYNOPSIS
    Checks if user app registration is prevented

.DESCRIPTION

    Only administrators SHALL be allowed to register applications.

.EXAMPLE
    Test-MtCisaAppRegistration

    Returns true if disabled
#>

Function Test-MtCisaAppRegistration {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $testResult = $result.defaultUserRolePermissions.allowedToCreateApps -eq $false

    if ($testResult) {
        $testResultMarkdown = "Well done. **[Users can register applications](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings)** is set to **No** in your tenant."
    } else {
        $testResultMarkdown = "Your tenant is configured with **[Users can register applications](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings)** set to **Yes**. The recommended setting is **No**."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}