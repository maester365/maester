<#
.SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show geographic location in push and passwordless notifications is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be showing geographic location in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the result of
     graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-MtEidscaAM10

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayLocationInformationRequiredState.includeTarget.id -eq 'all_users'
#>

Function Test-MtEidscaAM10 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    [string]$tenantValue = $result.featureSettings.displayLocationInformationRequiredState.includeTarget.id
    $testResult = $tenantValue -eq 'all_users'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
