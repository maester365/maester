<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - State is set to 'enabled'

.DESCRIPTION

    Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.

    Queries policies/authenticationMethodsPolicy
    and returns the result of
     graph/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.state -eq 'enabled'

.EXAMPLE
    Test-MtEidscaAG02

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.state -eq 'enabled'
#>

function Test-MtEidscaAG02 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    [string]$tenantValue = $result.reportSuspiciousActivitySettings.state
    $testResult = $tenantValue -eq 'enabled'
    $tenantValueNotSet = $null -eq $tenantValue -and 'enabled' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'enabled'** for **policies/authenticationMethodsPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
