<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Allow self-service set up is set to 'true'

.DESCRIPTION

    Allows users to register a FIDO key through the MySecurityInfo portal, even if enabled by Authentication Methods policy.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isSelfServiceRegistrationAllowed -eq 'true'

.EXAMPLE
    Test-MtEidscaAF02

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isSelfServiceRegistrationAllowed -eq 'true'
#>

Function Test-MtEidscaAF02 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    [string]$tenantValue = $result.isSelfServiceRegistrationAllowed
    $testResult = $tenantValue -eq 'true'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
