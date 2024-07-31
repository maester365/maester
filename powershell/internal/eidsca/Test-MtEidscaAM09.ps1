<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Show geographic location in push and passwordless notifications is set to 'enabled'

.DESCRIPTION

    Determines whether the user's Authenticator app will show them the geographic location of where the authentication request originated from.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.state -eq 'enabled'

.EXAMPLE
    Test-MtEidscaAM09

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.state -eq 'enabled'
#>

function Test-MtEidscaAM09 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of Microsoft Authenticator is not enabled.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    [string]$tenantValue = $result.featureSettings.displayLocationInformationRequiredState.state
    $testResult = $tenantValue -eq 'enabled'
    $tenantValueNotSet = $null -eq $tenantValue -and 'enabled' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
