<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restrict specific keys is set to 'block'

.DESCRIPTION

    Defines if list of AADGUID will be used to allow or block registration.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and checks if keyRestrictions.enforcementType is set to 'block'

.EXAMPLE
    Get-EidscaEIDSCA.AF06

    Returns the value of keyRestrictions.enforcementType at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
#>

Function Get-EidscaEIDSCA.AF06 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    if($result.keyRestrictions.enforcementType -eq 'block') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
