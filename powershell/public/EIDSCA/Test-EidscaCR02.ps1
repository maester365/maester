<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests??? is set to 'true'

.DESCRIPTION

    Specifies whether reviewers will receive notifications

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.notifyReviewers -eq 'true'

.EXAMPLE
    Test-EidscaCR02

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.notifyReviewers -eq 'true'
#>

Function Test-EidscaCR02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $testResult = $result.notifyReviewers -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
