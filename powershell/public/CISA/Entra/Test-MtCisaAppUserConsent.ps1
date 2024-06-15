<#
.SYNOPSIS
    Checks if user app consent is prevented

.DESCRIPTION

    Only administrators SHALL be allowed to consent to applications.

.EXAMPLE
    Test-MtCisaAppUserConsent

    Returns true if disabled
#>

Function Test-MtCisaAppUserConsent {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion v1.0

    $permissions = $result.defaultUserRolePermissions.permissionGrantPoliciesAssigned | Where-Object {`
        $_ -like "ManagePermissionGrantsForSelf.*" }

    $testResult = ($permissions|Measure-Object).Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant default user role permissions prevent app consent:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant default user role permissions allow app consent."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConsentPolicy -GraphObjects $permissions
    return $testResult
}