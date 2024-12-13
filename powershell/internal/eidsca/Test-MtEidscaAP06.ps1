<#
.SYNOPSIS
    Checks if Default Authorization Settings - User can join the tenant by email validation is set to 'false'

.DESCRIPTION

    Controls whether users can join the tenant by email validation. To join, the user must have an email address in a domain which matches one of the verified domains in the tenant.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization -eq 'false'

.EXAMPLE
    Test-MtEidscaAP06

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization -eq 'false'
#>

function Test-MtEidscaAP06 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    [string]$tenantValue = $result.allowEmailVerifiedUsersToJoinOrganization
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
