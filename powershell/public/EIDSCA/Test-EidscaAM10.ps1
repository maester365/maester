<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing geographic location in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-EidscaAM10

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users'
#>

Function Test-EidscaAM10 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users'

    Add-MtTestResultDetail -Result $testResult
}
