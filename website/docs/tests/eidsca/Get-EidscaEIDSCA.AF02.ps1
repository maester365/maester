<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Allow self-service set up is set to 'true'

.DESCRIPTION

    Allows users to register a FIDO key through the MySecurityInfo portal, even if enabled by Authentication Methods policy.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and checks if isSelfServiceRegistrationAllowed is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.AF02

    Returns the value of isSelfServiceRegistrationAllowed at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
#>

Function Get-EidscaEIDSCA.AF02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    if($result.isSelfServiceRegistrationAllowed -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
