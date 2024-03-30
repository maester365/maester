<#
.SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to read other users is set to 'true'

.DESCRIPTION

    Prevents all non-admins from reading user information from the directory. This flag doesn't prevent reading user information in other Microsoft services like Exchange Online.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true'

.EXAMPLE
    Test-EidscaAP14

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true'
#>

Function Test-EidscaAP14 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
