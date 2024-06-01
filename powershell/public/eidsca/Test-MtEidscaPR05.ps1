<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds is set to '60'

.DESCRIPTION

    The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -ge '60'

.EXAMPLE
    Test-MtEidscaPR05

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -ge '60'
#>

Function Test-MtEidscaPR05 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value
    $testResult = $tenantValue -ge '60'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is greater than or equal to **'60'** for **settings**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is greater than or equal to **'60'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
