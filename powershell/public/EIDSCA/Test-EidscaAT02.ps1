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
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    $tenantValue = $result.isUsableOnce
    $testResult = $tenantValue -eq 'false'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'false'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
