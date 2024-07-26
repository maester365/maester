<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restrict specific keys is set to 'true'

.DESCRIPTION

    Defines if list of AADGUID will be used to allow or block registration.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') -eq 'true'

.EXAMPLE
    Test-MtEidscaAF06

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block') -eq 'true'
#>

function Test-MtEidscaAF06 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAuthMethods -notcontains 'Fido2' -or (Test-MtEidscaAF04) -eq $false ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled and key restriction not enforced.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    [string]$tenantValue = $result.keyRestrictions.aaGuids -notcontains $null -and ($result.keyRestrictions.enforcementType -eq 'allow' -or $result.keyRestrictions.enforcementType -eq 'block')
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
