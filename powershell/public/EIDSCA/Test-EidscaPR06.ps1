<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold is set to '10'

.DESCRIPTION

    How many failed sign-ins are allowed on an account before its first lockout. If the first sign-in after a lockout also fails, the account locks out again.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'LockoutThreshold' | select-object -expand value -eq '10'

.EXAMPLE
    Test-EidscaPR06

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutThreshold' | select-object -expand value -eq '10'
#>

Function Test-EidscaPR06 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $tenantValue = $result.values | where-object name -eq 'LockoutThreshold' | select-object -expand value
    $testResult = $tenantValue -eq '10'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'10'** for **settings**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'10'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
