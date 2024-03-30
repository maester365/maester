<#
.SYNOPSIS
    Checks if Default Authorization Settings - Sign-up for email based subscription is set to 'false'

.DESCRIPTION

    Indicates whether users can sign up for email based subscriptions.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowedToSignUpEmailBasedSubscriptions -eq 'false'

.EXAMPLE
    Test-MtEidscaAP05

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToSignUpEmailBasedSubscriptions -eq 'false'
#>

Function Test-MtEidscaAP05 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $tenantValue = $result.allowedToSignUpEmailBasedSubscriptions
    $testResult = $tenantValue -eq 'false'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'false'** for **policies/authorizationPolicy**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
