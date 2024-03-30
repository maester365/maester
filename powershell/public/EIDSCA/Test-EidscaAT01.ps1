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
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    $tenantValue = $result.state
    $testResult = $tenantValue -eq 'enabled'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
