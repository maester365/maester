<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - State is set to 'enabled'

.DESCRIPTION

    Whether the Authenticator App is enabled in the tenant.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').state -eq 'enabled'

.EXAMPLE
    Test-EidscaAM01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').state -eq 'enabled'
#>

Function Test-EidscaAM01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $tenantValue = $result.state
    $testResult = $tenantValue -eq 'enabled'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
