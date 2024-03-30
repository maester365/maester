<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds is set to '60'

.DESCRIPTION

    The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -eq '60'

.EXAMPLE
    Test-EidscaPR05

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -eq '60'
#>

Function Test-EidscaPR05 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $tenantValue = $result.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value
    $testResult = $tenantValue -eq '60'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'60'** for **settings**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'60'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
