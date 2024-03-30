<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Consent request duration (days)??? is set to '30'

.DESCRIPTION

    Specifies the duration the request is active before it automatically expires if no decision is applied

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.requestDurationInDays -eq '30'

.EXAMPLE
    Test-EidscaCR04

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.requestDurationInDays -eq '30'
#>

Function Test-EidscaCR04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $testResult = $result.requestDurationInDays -eq '30'

    Add-MtTestResultDetail -Result $testResult
}
