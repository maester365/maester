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

function Test-MtEidscaCP04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $SettingsApiAvailable -notcontains 'EnableAdminConsentRequests' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Settings value is not available. This may be due to the change that this API is no longer available for recent created tenants.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'EnableAdminConsentRequests' | select-object -expand value
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = $null -eq $tenantValue -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
