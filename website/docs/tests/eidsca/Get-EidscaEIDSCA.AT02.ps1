<#
.SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - One-time is set to 'false'

.DESCRIPTION

    Determines whether the pass is limited to a one-time use.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    and checks if isUsableOnce is set to 'false'

.EXAMPLE
    Get-EidscaEIDSCA.AT02

    Returns the value of isUsableOnce at policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
#>

Function Get-EidscaEIDSCA.AT02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    if($result.isUsableOnce -eq 'false') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
