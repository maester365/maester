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

Function Test-MtEidscaPR03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    [string]$tenantValue = $result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value
    $testResult = $tenantValue -eq 'True'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'True'** for **settings**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'True'** for **settings**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
