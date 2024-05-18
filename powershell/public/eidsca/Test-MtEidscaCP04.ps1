<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Users can request admin consent to apps they are unable to consent to is set to 'true'

.DESCRIPTION

    If this option is set to enabled, then users request admin consent to any app that requires access to data they do not have the permission to grant. If this option is set to disabled, then users must contact their admin to request to consent in order to use the apps they need.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true'

.EXAMPLE
    Test-MtEidscaCP04

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value -eq 'true'
#>

Function Test-MtEidscaCP04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value
    $testResult = $tenantValue -eq 'true'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'true'** for **settings**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
