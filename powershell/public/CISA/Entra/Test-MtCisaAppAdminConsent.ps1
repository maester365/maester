<#
.SYNOPSIS
    Checks if admin consent workflow is configured with reviewers

.DESCRIPTION

    An admin consent workflow SHALL be configured for applications.

.EXAMPLE
    Test-MtCisaAppAdminConsent

    Returns true if configured
#>

Function Test-MtCisaAppAdminConsent {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion v1.0

    $reviewers = $result | Where-Object {`
        $_.isEnabled -and `
        $_.notifyReviewers -and `
        $_.reviewers.Count -ge 1 } | Select-Object -ExpandProperty reviewers

    $testResult = $reviewers.Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant admin consent request policy has at least 1 reviewer:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant admin consent request policy is not configured."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType AuthorizationPolicy -GraphObjects "Admin consent"
    return $testResult
}