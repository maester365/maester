<#
.SYNOPSIS
    Checks if Default Authorization Settings - User consent policy assigned for applications is set to 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

.DESCRIPTION

    Defines if user consent to apps is allowed, and if it is, which app consent policy (permissionGrantPolicy) governs the permissions.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

.EXAMPLE
    Test-EidscaAP08

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low'
#>

Function Test-EidscaAP08 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.permissionGrantPolicyIdsAssignedToDefaultUserRole[2] -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

    Add-MtTestResultDetail -Result $testResult
}
