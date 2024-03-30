<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Consent request duration (days)??? is set to '30'

.DESCRIPTION

    Specifies the duration the request is active before it automatically expires if no decision is applied

    Queries policies/adminConsentRequestPolicy
    and checks if requestDurationInDays is set to '30'

.EXAMPLE
    Get-EidscaEIDSCA.CR04

    Returns the value of requestDurationInDays at policies/adminConsentRequestPolicy
#>

Function Get-EidscaEIDSCA.CR04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    if($result.requestDurationInDays -eq '30') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
