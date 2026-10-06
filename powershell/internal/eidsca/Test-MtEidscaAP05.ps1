function Test-MtEidscaAP05 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Sign-up for email based subscription is set to 'false'

    .DESCRIPTION

    Indicates whether users can sign up for email based subscriptions.

    Queries policies/authorizationPolicy
    and returns the tenant value of
    graph/policies/authorizationPolicy.allowedToSignUpEmailBasedSubscriptions

    The native test EIDSCA.AP05 passes when this value -eq 'false'.

    .EXAMPLE
    Test-MtEidscaAP05

    Returns the tenant value of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToSignUpEmailBasedSubscriptions
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $rawValue = $result.allowedToSignUpEmailBasedSubscriptions
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'false'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'false' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'false'** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Medium'

    return $tenantValue
}
