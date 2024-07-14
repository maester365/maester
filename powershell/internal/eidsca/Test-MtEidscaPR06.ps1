<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold is set to '10'

.DESCRIPTION

    How many failed sign-ins are allowed on an account before its first lockout. If the first sign-in after a lockout also fails, the account locks out again.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'LockoutThreshold' | select-object -expand value -eq '10'

.EXAMPLE
    Test-MtEidscaPR06

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'LockoutThreshold' | select-object -expand value -eq '10'
#>

Function Test-MtEidscaPR06 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'LockoutThreshold' | select-object -expand value
    $testResult = $tenantValue -eq '10'
    $tenantValueNotSet = $null -eq $tenantValue -and '10' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'10'** for **settings**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'10'** for **settings**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'10'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
