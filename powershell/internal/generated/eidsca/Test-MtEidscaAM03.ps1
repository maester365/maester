function Test-MtEidscaAM03 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - Microsoft Authenticator - Require number matching for push notifications is set to 'enabled'

    .DESCRIPTION

    Defines if number matching is required for MFA notifications.

    Queries policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')
    and returns the tenant value of
    graph/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.state

    The native test EIDSCA.AM03 passes when this value -eq 'enabled'.

    .EXAMPLE
    Test-MtEidscaAM03

    Returns the tenant value of graph.microsoft.com/beta/policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator').featureSettings.numberMatchingRequiredState.state
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')" -ApiVersion beta

    $rawValue = $result.featureSettings.numberMatchingRequiredState.state
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'enabled'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'enabled' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'enabled'** for **policies/authenticationMethodsPolicy/authenticationMethodConfigurations('MicrosoftAuthenticator')**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $tenantValue
}
