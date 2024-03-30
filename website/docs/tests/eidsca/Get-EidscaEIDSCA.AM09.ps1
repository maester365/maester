<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications is set to 'enabled'

.DESCRIPTION

    Determines whether the user's Authenticator app will show them the geographic location of where the authentication request originated from.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if featureSettings.displayLocationInformationRequiredState.state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AM09

    Returns the value of featureSettings.displayLocationInformationRequiredState.state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM09 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.featureSettings.displayLocationInformationRequiredState.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
