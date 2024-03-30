<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Allow self-service set up is set to 'true'

.DESCRIPTION

    Allows users to register a FIDO key through the MySecurityInfo portal, even if enabled by Authentication Methods policy.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isSelfServiceRegistrationAllowed -eq 'true'

.EXAMPLE
    Test-EidscaAF02

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isSelfServiceRegistrationAllowed -eq 'true'
#>

Function Test-EidscaAF02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $testResult = $result.isSelfServiceRegistrationAllowed -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
