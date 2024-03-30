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
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $tenantValue = $result.permissionGrantPolicyIdsAssignedToDefaultUserRole[2]
    $testResult = $tenantValue -eq 'ManagePermissionGrantsForSelf.microsoft-user-default-low'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'ManagePermissionGrantsForSelf.microsoft-user-default-low'** for **policies/authorizationPolicy**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'ManagePermissionGrantsForSelf.microsoft-user-default-low'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
