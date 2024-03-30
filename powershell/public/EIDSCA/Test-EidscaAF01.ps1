<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - State is set to 'enabled'

.DESCRIPTION

    Whether the FIDO2 security keys is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').state -eq 'enabled'

.EXAMPLE
    Test-EidscaAF01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').state -eq 'enabled'
#>

Function Test-EidscaAF01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $testResult = $result.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
