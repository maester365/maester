<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing number matching in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-EidscaAM04

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users'
#>

Function Test-EidscaAM04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users'

    Add-MtTestResultDetail -Result $testResult
}
