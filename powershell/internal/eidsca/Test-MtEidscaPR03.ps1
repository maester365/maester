<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Enforce custom list is set to 'True'

.DESCRIPTION

    When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True'

.EXAMPLE
    Test-MtEidscaPR03

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True'
#>

function Test-MtEidscaPR03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $SettingsApiAvailable -notcontains 'EnableBannedPasswordCheck' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Settings value is not available. This may be due to the change that this API is no longer available for recent created tenants.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value
    $testResult = $tenantValue -eq 'True'
    $tenantValueNotSet = $null -eq $tenantValue -and 'True' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'True'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'True'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'True'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
