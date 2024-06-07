<#
.SYNOPSIS
    Checks if Authentication Method - FIDO2 security key - Restricted is set to 'true'

.DESCRIPTION

    You can work with your Security key provider to determine the AAGuids of their devices for allowing or blocking usage.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.aaGuids -notcontains $null -eq 'true'

.EXAMPLE
    Test-MtEidscaAF05

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2').keyRestrictions.aaGuids -notcontains $null -eq 'true'
#>

Function Test-MtEidscaAF05 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Fido2')" -ApiVersion beta

    [string]$tenantValue = $result.keyRestrictions.aaGuids -notcontains $null
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = $tenantValue -eq $null -and 'true' -notlike '*$null*'

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
