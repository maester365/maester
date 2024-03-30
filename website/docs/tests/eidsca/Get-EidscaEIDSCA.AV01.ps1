<#
.SYNOPSIS
    Checks if Authentication Method - Voice call - State is set to 'disabled'

.DESCRIPTION

    Whether the Voice call is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
    and checks if state is set to 'disabled'

.EXAMPLE
    Get-EidscaEIDSCA.AV01

    Returns the value of state at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
#>

Function Get-EidscaEIDSCA.AV01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta

    if($result.state -eq 'disabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
