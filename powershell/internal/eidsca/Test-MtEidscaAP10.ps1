<#
.SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create Apps is set to 'false'

.DESCRIPTION

    Controls if non-admin users may register custom-developed applications for use within this directory.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps -eq 'false'

.EXAMPLE
    Test-MtEidscaAP10

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateApps -eq 'false'
#>

function Test-MtEidscaAP10 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    [string]$tenantValue = $result.defaultUserRolePermissions.allowedToCreateApps
    $testResult = $tenantValue -eq 'false'
    $tenantValueNotSet = $null -eq $tenantValue -and 'false' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'false'** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
