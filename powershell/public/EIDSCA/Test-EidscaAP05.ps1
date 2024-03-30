<#
.SYNOPSIS
    Checks if Default Authorization Settings - Sign-up for email based subscription is set to 'false'

.DESCRIPTION

    Indicates whether users can sign up for email based subscriptions.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowedToSignUpEmailBasedSubscriptions -eq 'false'

.EXAMPLE
    Test-EidscaAP05

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToSignUpEmailBasedSubscriptions -eq 'false'
#>

Function Test-EidscaAP05 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.allowedToSignUpEmailBasedSubscriptions -eq 'false'

    Add-MtTestResultDetail -Result $testResult
}
