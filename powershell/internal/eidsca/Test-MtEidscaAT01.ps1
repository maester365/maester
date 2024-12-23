<#
.SYNOPSIS
    Checks if Authentication Method - Temporary Access Pass - State is set to 'enabled'

.DESCRIPTION

    Whether the Temporary Access Pass is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass').state -eq 'enabled'

.EXAMPLE
    Test-MtEidscaAT01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass').state -eq 'enabled'
#>

function Test-MtEidscaAT01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')" -ApiVersion beta

    [string]$tenantValue = $result.state
    $testResult = $tenantValue -eq 'enabled'
    $tenantValueNotSet = $null -eq $tenantValue -and 'enabled' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('TemporaryAccessPass')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
