<#
.SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create Apps is set to 'false'

.DESCRIPTION

    Controls if non-admin users may register custom-developed applications for use within this directory.

    Queries policies/authorizationPolicy
    and checks if defaultUserRolePermissions.allowedToCreateApps is set to 'false'

.EXAMPLE
    Get-EidscaEIDSCA.AP10

    Returns the value of defaultUserRolePermissions.allowedToCreateApps at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP10 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.defaultUserRolePermissions.allowedToCreateApps -eq 'false') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
