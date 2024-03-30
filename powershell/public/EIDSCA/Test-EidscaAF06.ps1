<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restrict specific keys is set to 'block'

.DESCRIPTION

    Defines if list of AADGUID will be used to allow or block registration.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.enforcementType -eq 'block'

.EXAMPLE
    Test-EidscaAF06

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.enforcementType -eq 'block'
#>

Function Test-EidscaAF06 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $testResult = $result.keyRestrictions.enforcementType -eq 'block'

    Add-MtTestResultDetail -Result $testResult
}
