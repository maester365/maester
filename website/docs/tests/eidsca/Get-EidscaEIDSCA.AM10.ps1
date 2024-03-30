<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing geographic location in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if featureSettings.displayLocationInformationRequiredState.includeTarget.id is set to 'all_users'

.EXAMPLE
    Get-EidscaEIDSCA.AM10

    Returns the value of featureSettings.displayLocationInformationRequiredState.includeTarget.id at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM10 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
