<#
.SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset is set to 'true'

.DESCRIPTION

    Designates whether users in this directory can reset their own password.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowedToUseSSPR -eq 'true'

.EXAMPLE
    Test-MtEidscaAP01

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToUseSSPR -eq 'true'
#>

Function Test-MtEidscaAP01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $tenantValue = $result.allowedToUseSSPR
    $testResult = $tenantValue -eq 'true'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'true'** for **policies/authorizationPolicy**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
