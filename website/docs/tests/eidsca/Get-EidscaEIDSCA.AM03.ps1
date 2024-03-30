<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Require number matching for push notifications is set to 'enabled'

.DESCRIPTION

    Defines if number matching is required for MFA notifications.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if featureSettings.numberMatchingRequiredState.state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AM03

    Returns the value of featureSettings.numberMatchingRequiredState.state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.featureSettings.numberMatchingRequiredState.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
