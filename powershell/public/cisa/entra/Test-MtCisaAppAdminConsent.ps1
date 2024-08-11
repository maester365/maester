<#
.SYNOPSIS
    Checks if admin consent workflow is configured with reviewers

.DESCRIPTION
    An admin consent workflow SHALL be configured for applications.

.EXAMPLE
    Test-MtCisaAppAdminConsent

    Returns true if configured

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAppAdminConsent
#>
function Test-MtCisaAppAdminConsent {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection Graph)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion v1.0

    $reviewers = $result | Where-Object {`
        $_.isEnabled -and `
        $_.notifyReviewers -and `
        $_.reviewers.Count -ge 1 } | Select-Object -ExpandProperty reviewers

    $testResult = ($reviewers|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant admin consent request policy has at least 1 reviewer."
    } else {
        $testResultMarkdown = "Your tenant admin consent request policy is not configured."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}