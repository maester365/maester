<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Consent request duration (days) is set to '30'

.DESCRIPTION

    Specifies the duration the request is active before it automatically expires if no decision is applied

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.requestDurationInDays -eq '30'

.EXAMPLE
    Test-MtEidscaCR04

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.requestDurationInDays -eq '30'
#>

Function Test-MtEidscaCR04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $tenantValue = $result.requestDurationInDays | Out-String -NoNewLine
    $testResult = $tenantValue -eq '30'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'30'** for **policies/adminConsentRequestPolicy**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'30'** for **policies/adminConsentRequestPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
