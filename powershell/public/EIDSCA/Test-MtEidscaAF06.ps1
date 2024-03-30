<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restrict specific keys is set to 'block'

.DESCRIPTION

    Defines if list of AADGUID will be used to allow or block registration.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.enforcementType -eq 'block'

.EXAMPLE
    Test-MtEidscaAF06

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.enforcementType -eq 'block'
#>

Function Test-MtEidscaAF06 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    $tenantValue = $result.keyRestrictions.enforcementType
    $testResult = $tenantValue -eq 'block'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'block'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'block'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
