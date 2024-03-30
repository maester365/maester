<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Enforce custom list is set to 'True'

.DESCRIPTION

    When enabled, the words in the list below are used in the banned password system to prevent easy-to-guess passwords.

    Queries settings
    and checks if values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value is set to 'True'

.EXAMPLE
    Get-EidscaEIDSCA.PR03

    Returns the value of values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.PR03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'EnableBannedPasswordCheck' | select-object -expand value -eq 'True') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
