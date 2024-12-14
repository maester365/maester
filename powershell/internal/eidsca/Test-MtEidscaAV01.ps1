<#
.SYNOPSIS
    Checks if Authentication Method - Voice call - State is set to 'disabled'

.DESCRIPTION

    Whether the Voice call is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice').state -eq 'disabled'

.EXAMPLE
    Test-MtEidscaAV01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice').state -eq 'disabled'
#>

function Test-MtEidscaAV01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')" -ApiVersion beta

    [string]$tenantValue = $result.state
    $testResult = $tenantValue -eq 'disabled'
    $tenantValueNotSet = $null -eq $tenantValue -and 'disabled' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'disabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'disabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'disabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('Voice')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
