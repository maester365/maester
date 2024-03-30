<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Block user consent for risky apps is set to 'true'

.DESCRIPTION

    Defines whether user consent will be blocked when a risky request is detected

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'

.EXAMPLE
    Test-EidscaCP03

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'
#>

Function Test-EidscaCP03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $testResult = $result.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
