<#
.SYNOPSIS
    Checks if Authentication Method - Voice call - State is set to 'disabled'

.DESCRIPTION

    Whether the Voice call is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice').state -eq 'disabled'

.EXAMPLE
    Test-EidscaAV01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice').state -eq 'disabled'
#>

Function Test-EidscaAV01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta

    $testResult = $result.state -eq 'disabled'

    Add-MtTestResultDetail -Result $testResult
}
