<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show application name in push and passwordless notifications is set to 'enabled'

.DESCRIPTION

    Determines whether the user's Authenticator app will show them the client app they are signing into.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if featureSettings.displayAppInformationRequiredState.state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AM06

    Returns the value of featureSettings.displayAppInformationRequiredState.state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM06 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.featureSettings.displayAppInformationRequiredState.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
