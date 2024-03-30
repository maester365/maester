<#
.SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to read other users is set to 'true'

.DESCRIPTION

    Prevents all non-admins from reading user information from the directory. This flag doesn't prevent reading user information in other Microsoft services like Exchange Online.

    Queries policies/authorizationPolicy
    and checks if defaultUserRolePermissions.allowedToReadOtherUsers is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.AP14

    Returns the value of defaultUserRolePermissions.allowedToReadOtherUsers at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP14 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
