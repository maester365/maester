<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - Included users/groups is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.

    Queries policies/authenticationMethodsPolicy
    and returns the result of
     graph/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-MtEidscaAG03

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'
#>

function Test-MtEidscaAG03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    [string]$tenantValue = $result.reportSuspiciousActivitySettings.includeTarget.id
    $testResult = $tenantValue -eq 'all_users'
    $tenantValueNotSet = $null -eq $tenantValue -and 'all_users' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'all_users'** for **policies/authenticationMethodsPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
