<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Mode is set to 'Enforce'

.DESCRIPTION

    If set to Enforce, users will be prevented from setting banned passwords and the attempt will be logged. If set to Audit, the attempt will only be logged.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce'

.EXAMPLE
    Test-MtEidscaPR01

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce'
#>

function Test-MtEidscaPR01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $SettingsApiAvailable -notcontains 'BannedPasswordCheckOnPremisesMode' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Settings value is not available. This may be due to the change that this API is no longer available for recent created tenants.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value
    $testResult = $tenantValue -eq 'Enforce'
    $tenantValueNotSet = $null -eq $tenantValue -and 'Enforce' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'Enforce'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'Enforce'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'Enforce'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
