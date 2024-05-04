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
        $testResultMarkdown = "Well done. Your tenant default user role permissions prevent app creation:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant default user role permissions allow app creation."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType AuthorizationPolicy -GraphObjects $result.displayName
    return $testResult
}