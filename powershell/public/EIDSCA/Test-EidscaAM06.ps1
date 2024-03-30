<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications is set to 'enabled'

.DESCRIPTION

    Determines whether the user's Authenticator app will show them the client app they are signing into.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayAppInformationRequiredState.state -eq 'enabled'

.EXAMPLE
    Test-EidscaAM06

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayAppInformationRequiredState.state -eq 'enabled'
#>

Function Test-EidscaAM06 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.featureSettings.displayAppInformationRequiredState.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
