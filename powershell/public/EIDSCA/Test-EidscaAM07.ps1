<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing app information in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayAppInformationRequiredState.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-EidscaAM07

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayAppInformationRequiredState.includeTarget.id -eq 'all_users'
#>

Function Test-EidscaAM07 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.featureSettings.displayAppInformationRequiredState.includeTarget.id -eq 'all_users'

    Add-MtTestResultDetail -Result $testResult
}
