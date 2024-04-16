<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire is set to 'true'

.DESCRIPTION

    Specifies whether reviewers will receive reminder emails

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.notifyReviewers -eq 'true'

.EXAMPLE
    Test-MtEidscaCR03

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.notifyReviewers -eq 'true'
#>

Function Test-MtEidscaCR03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $tenantValue = $result.notifyReviewers | Out-String -NoNewLine
    $testResult = $tenantValue -eq 'true'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'true'** for **policies/adminConsentRequestPolicy**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
