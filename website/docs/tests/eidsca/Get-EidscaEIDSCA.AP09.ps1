<#
.SYNOPSIS
    Checks if Default Authorization Settings - Risk-based step-up consent is set to 'false'

.DESCRIPTION

    Indicates whether user consent for risky apps is allowed. For example, consent requests for newly registered multi-tenant apps that are not publisher verified and require non-basic permissions are considered risky.

    Queries policies/authorizationPolicy
    and checks if allowUserConsentForRiskyApps is set to 'false'

.EXAMPLE
    Get-EidscaEIDSCA.AP09

    Returns the value of allowUserConsentForRiskyApps at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP09 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.allowUserConsentForRiskyApps -eq 'false') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
