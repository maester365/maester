<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - State is set to 'enabled'

.DESCRIPTION

    Whether the FIDO2 security keys is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').state -eq 'enabled'

.EXAMPLE
    Test-MtEidscaAF01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').state -eq 'enabled'
#>

Function Test-MtEidscaAF01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $tenantValue = $result.state
    $testResult = $tenantValue -eq 'enabled'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
