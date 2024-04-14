<#
.SYNOPSIS
    Checks if Authentication Method - Voice call - State is set to 'disabled'

.DESCRIPTION

    Whether the Voice call is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice').state -eq 'disabled'

.EXAMPLE
    Test-MtEidscaAV01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice').state -eq 'disabled'
#>

Function Test-MtEidscaAV01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta

    $tenantValue = ($result.state).ToString()
    $testResult = $tenantValue -eq 'disabled'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'disabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'disabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
