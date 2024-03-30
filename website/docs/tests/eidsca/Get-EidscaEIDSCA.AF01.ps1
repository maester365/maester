<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - State is set to 'enabled'

.DESCRIPTION

    Whether the FIDO2 security keys is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and checks if state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AF01

    Returns the value of state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
#>

Function Get-EidscaEIDSCA.AF01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    if($result.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
