<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Enforce attestation is set to 'true'

.DESCRIPTION

    Requires the FIDO security key metadata to be published and verified with the FIDO Alliance Metadata Service, and also pass Microsoft???s additional set of validation testing.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and checks if isAttestationEnforced is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.AF03

    Returns the value of isAttestationEnforced at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
#>

Function Get-EidscaEIDSCA.AF03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    if($result.isAttestationEnforced -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
