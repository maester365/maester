<#
.SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to read other users is set to 'true'

.DESCRIPTION

    Prevents all non-admins from reading user information from the directory. This flag doesn't prevent reading user information in other Microsoft services like Exchange Online.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true'

.EXAMPLE
    Test-MtEidscaAP14

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.defaultUserRolePermissions.allowedToReadOtherUsers -eq 'true'
#>

function Test-MtEidscaAP14 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    [string]$tenantValue = $result.defaultUserRolePermissions.allowedToReadOtherUsers
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = ($null -eq $tenantValue -or $tenantValue -eq "") -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Info'

    return $tenantValue
}
