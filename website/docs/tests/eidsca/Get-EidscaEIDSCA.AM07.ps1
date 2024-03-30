<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing app information in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if featureSettings.displayAppInformationRequiredState.includeTarget.id is set to 'all_users'

.EXAMPLE
    Get-EidscaEIDSCA.AM07

    Returns the value of featureSettings.displayAppInformationRequiredState.includeTarget.id at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM07 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.featureSettings.displayAppInformationRequiredState.includeTarget.id -eq 'all_users') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
