<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Group owner consent for apps accessing data is set to 'False'

.DESCRIPTION

    Group and team owners can authorize applications, such as applications published by third-party vendors, to access your organization's data associated with a group. For example, a team owner in Microsoft Teams can allow an app to read all Teams messages in the team, or list the basic profile of a group's members.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value -eq 'False'

.EXAMPLE
    Test-MtEidscaCP01

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value -eq 'False'
#>

function Test-MtEidscaCP01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $SettingsApiAvailable -notcontains 'EnableGroupSpecificConsent' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Settings value is not available. This may be due to the change that this API is no longer available for recent created tenants.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value
    $testResult = $tenantValue -eq 'False'
    $tenantValueNotSet = $null -eq $tenantValue -and 'False' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'False'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'False'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'False'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
