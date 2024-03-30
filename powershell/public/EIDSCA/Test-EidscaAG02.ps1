<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - State is set to 'enabled'

.DESCRIPTION

    Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.

    Queries policies/authenticationMethodsPolicy
    and returns the result of
     graph/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.state -eq 'enabled'

.EXAMPLE
    Test-EidscaAG02

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.state -eq 'enabled'
#>

Function Test-EidscaAG02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    $testResult = $result.reportSuspiciousActivitySettings.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
