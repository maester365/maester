<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Enforce attestation is set to 'true'

.DESCRIPTION

    Requires the FIDO security key metadata to be published and verified with the FIDO Alliance Metadata Service, and also pass Microsoft???s additional set of validation testing.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isAttestationEnforced -eq 'true'

.EXAMPLE
    Test-EidscaAF03

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isAttestationEnforced -eq 'true'
#>

Function Test-EidscaAF03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $testResult = $result.isAttestationEnforced -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
