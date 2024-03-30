<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing number matching in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if featureSettings.numberMatchingRequiredState.includeTarget.id is set to 'all_users'

.EXAMPLE
    Get-EidscaEIDSCA.AM04

    Returns the value of featureSettings.numberMatchingRequiredState.includeTarget.id at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
