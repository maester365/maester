<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Enforce attestation is set to 'true'

.DESCRIPTION

    Requires the FIDO security key metadata to be published and verified with the FIDO Alliance Metadata Service, and also pass Microsoft's additional set of validation testing.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isAttestationEnforced -eq 'true'

.EXAMPLE
    Test-MtEidscaAF03

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').isAttestationEnforced -eq 'true'
#>

function Test-MtEidscaAF03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAuthMethods -notcontains 'Fido2' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of FIDO2 security keys is not enabled.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    [string]$tenantValue = $result.isAttestationEnforced
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
