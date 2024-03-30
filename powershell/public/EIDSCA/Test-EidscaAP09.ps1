<#
.SYNOPSIS
    Checks if Default Authorization Settings - Risk-based step-up consent is set to 'false'

.DESCRIPTION

    Indicates whether user consent for risky apps is allowed. For example, consent requests for newly registered multi-tenant apps that are not publisher verified and require non-basic permissions are considered risky.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowUserConsentForRiskyApps -eq 'false'

.EXAMPLE
    Test-EidscaAP09

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowUserConsentForRiskyApps -eq 'false'
#>

Function Test-EidscaAP09 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.allowUserConsentForRiskyApps -eq 'false'

    Add-MtTestResultDetail -Result $testResult
}
