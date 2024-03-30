<#
.SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - State is set to 'enabled'

.DESCRIPTION

    Whether the Temporary Access Pass is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    and checks if state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AT01

    Returns the value of state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
#>

Function Get-EidscaEIDSCA.AT01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    if($result.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
