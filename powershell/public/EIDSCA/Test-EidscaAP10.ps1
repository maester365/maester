<#
.SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create Apps is set to 'false'

.DESCRIPTION

    Controls if non-admin users may register custom-developed applications for use within this directory.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps -eq 'false'

.EXAMPLE
    Test-EidscaAP10

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps -eq 'false'
#>

Function Test-EidscaAP10 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.defaultUserRolePermissions.allowedToCreateApps -eq 'false'

    Add-MtTestResultDetail -Result $testResult
}
