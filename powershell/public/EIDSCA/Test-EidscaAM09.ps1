<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications is set to 'enabled'

.DESCRIPTION

    Determines whether the user's Authenticator app will show them the geographic location of where the authentication request originated from.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.state -eq 'enabled'

.EXAMPLE
    Test-EidscaAM09

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.state -eq 'enabled'
#>

Function Test-EidscaAM09 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.featureSettings.displayLocationInformationRequiredState.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
