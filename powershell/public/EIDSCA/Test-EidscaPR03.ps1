<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Enforce custom list is set to 'True'

.DESCRIPTION

    When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True'

.EXAMPLE
    Test-EidscaPR03

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True'
#>

Function Test-EidscaPR03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $testResult = $result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True'

    Add-MtTestResultDetail -Result $testResult
}
