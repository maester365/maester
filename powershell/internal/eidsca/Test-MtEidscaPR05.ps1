<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds is greater or equal to '60'

.DESCRIPTION

    The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -ge '60'

.EXAMPLE
    Test-MtEidscaPR05

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -ge '60'
#>

function Test-MtEidscaPR05 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    
    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value
    $testResult = [int]$tenantValue -ge [int]'60'
    $tenantValueNotSet = $null -eq $tenantValue -and '60' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is greater than or equal to **'60'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'60'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is greater than or equal to **'60'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
