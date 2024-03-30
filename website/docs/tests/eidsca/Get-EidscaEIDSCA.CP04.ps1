<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to??? is set to 'true'

.DESCRIPTION

    If this option is set to enabled, then users request admin consent to any app that requires access to data they do not have the permission to grant. If this option is set to disabled, then users must contact their admin to request to consent in order to use the apps they need.

    Queries settings
    and checks if values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.CP04

    Returns the value of values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.CP04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
