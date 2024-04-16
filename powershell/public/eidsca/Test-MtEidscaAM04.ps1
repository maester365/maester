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

Function Test-MtEidscaAM04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $tenantValue = $result.featureSettings.numberMatchingRequiredState.includeTarget.id | Out-String -NoNewLine
    $testResult = $tenantValue -eq 'all_users'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
