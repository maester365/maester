<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to??? is set to 'true'

.DESCRIPTION

    If this option is set to enabled, then users request admin consent to any app that requires access to data they do not have the permission to grant. If this option is set to disabled, then users must contact their admin to request to consent in order to use the apps they need.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true'

.EXAMPLE
    Test-EidscaCP04

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true'
#>

Function Test-EidscaCP04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $testResult = $result.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
