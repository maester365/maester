<#
.SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - One-time is set to 'false'

.DESCRIPTION

    Determines whether the pass is limited to a one-time use.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass').isUsableOnce -eq 'false'

.EXAMPLE
    Test-EidscaAT02

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass').isUsableOnce -eq 'false'
#>

Function Test-EidscaAT02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    $testResult = $result.isUsableOnce -eq 'false'

    Add-MtTestResultDetail -Result $testResult
}
