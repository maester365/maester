function Test-MtEidscaAM07 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Included users/groups to show application name in push and passwordless notifications is set to 'all_users'

    .DESCRIPTION

    Object Id or scope of users which will be showing app information in the Authenticator App.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the tenant value of
    graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayAppInformationRequiredState.includeTarget.id

    The native test EIDSCA.AM07 passes when this value -eq 'all_users'.

    .EXAMPLE
    Test-MtEidscaAM07

    Returns the tenant value of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.displayAppInformationRequiredState.includeTarget.id
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $rawValue = $result.featureSettings.displayAppInformationRequiredState.includeTarget.id
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'all_users'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'all_users' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'all_users'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $tenantValue
}
