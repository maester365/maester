<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups of number matching for push notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing number matching in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-MtEidscaAM04

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.includeTarget.id -eq 'all_users'
#>

function Test-MtEidscaAM04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAuthMethods -notcontains 'MicrosoftAuthenticator' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Authentication method of Microsoft Authenticator is not enabled.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    [string]$tenantValue = $result.featureSettings.numberMatchingRequiredState.includeTarget.id
    $testResult = $tenantValue -eq 'all_users'
    $tenantValueNotSet = $null -eq $tenantValue -and 'all_users' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
