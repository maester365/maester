<#
.SYNOPSIS
    Checks if Default Authorization Settings - User consent policy assigned for applications is set to 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

.DESCRIPTION

    Defines if user consent to apps is allowed, and if it is, which app consent policy (permissionGrantPolicy) governs the permissions.

    Queries policies/authorizationPolicy
    and checks if permissionGrantPolicyIdsAssignedToDefaultUserRole[2] is set to 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

.EXAMPLE
    Get-EidscaEIDSCA.AP08

    Returns the value of permissionGrantPolicyIdsAssignedToDefaultUserRole[2] at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP08 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
