<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Users can request admin consent to apps they are unable to consent to is set to 'true'

.DESCRIPTION

    Defines if admin consent request feature is enabled or disabled

    Queries policies/adminConsentRequestPolicy
    and checks if isEnabled is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.CR01

    Returns the value of isEnabled at policies/adminConsentRequestPolicy
#>

Function Get-EidscaEIDSCA.CR01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    if($result.isEnabled -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
