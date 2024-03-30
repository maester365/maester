<#
.SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - State is set to 'enabled'

.DESCRIPTION

    Whether the Temporary Access Pass is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass').state -eq 'enabled'

.EXAMPLE
    Test-EidscaAT01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass').state -eq 'enabled'
#>

Function Test-EidscaAT01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    $testResult = $result.state -eq 'enabled'

    Add-MtTestResultDetail -Result $testResult
}
