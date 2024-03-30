<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to is set to 'true'

.DESCRIPTION

    Defines if admin consent request feature is enabled or disabled

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.isEnabled -eq 'true'

.EXAMPLE
    Test-EidscaCR01

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.isEnabled -eq 'true'
#>

Function Test-EidscaCR01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $testResult = $result.isEnabled -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
