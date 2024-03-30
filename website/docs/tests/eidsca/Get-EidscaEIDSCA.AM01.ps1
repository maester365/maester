<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - State is set to 'enabled'

.DESCRIPTION

    Whether the Authenticator App is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and checks if state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AM01

    Returns the value of state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
#>

Function Get-EidscaEIDSCA.AM01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    if($result.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
