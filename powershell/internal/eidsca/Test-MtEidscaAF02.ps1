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

function Test-MtEidscaAF02 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAuthMethods -notcontains 'Fido2' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    [string]$tenantValue = $result.isSelfServiceRegistrationAllowed
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = $null -eq $tenantValue -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
