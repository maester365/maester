<#
.SYNOPSIS
    Checks if Default Authorization Settings - User can joint the tenant by email validation is set to 'false'

.DESCRIPTION

    Controls whether users can join the tenant by email validation. To join, the user must have an email address in a domain which matches one of the verified domains in the tenant.

    Queries policies/authorizationPolicy
    and checks if allowEmailVerifiedUsersToJoinOrganization is set to 'false'

.EXAMPLE
    Get-EidscaEIDSCA.AP06

    Returns the value of allowEmailVerifiedUsersToJoinOrganization at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP06 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.allowEmailVerifiedUsersToJoinOrganization -eq 'false') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
