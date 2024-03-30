<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Require number matching for push notifications is set to 'enabled'

.DESCRIPTION

    Defines if number matching is required for MFA notifications.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.state -eq 'enabled'

.EXAMPLE
    Test-EidscaAM03

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.state -eq 'enabled'
#>

Function Test-EidscaAM03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.featureSettings.numberMatchingRequiredState.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
