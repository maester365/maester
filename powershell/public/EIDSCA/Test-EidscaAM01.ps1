<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - State is set to 'enabled'

.DESCRIPTION

    Whether the Authenticator App is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').state -eq 'enabled'

.EXAMPLE
    Test-EidscaAM01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').state -eq 'enabled'
#>

Function Test-EidscaAM01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $testResult = $result.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
