<#
.SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset for administrators is set to 'false'

.DESCRIPTION

    Indicates whether administrators of the tenant can use the Self-Service Password Reset (SSPR). The policy applies to some critical critical roles in Microsoft Entra ID.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowedToUseSSPR -eq 'false'

.EXAMPLE
    Test-MtEidscaAP01

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToUseSSPR -eq 'false'
#>

Function Test-MtEidscaAP01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $tenantValue = $result.allowedToUseSSPR | Out-String -NoNewLine
    $testResult = $tenantValue -eq 'false'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'false'** for **policies/authorizationPolicy**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
