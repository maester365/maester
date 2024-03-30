<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout duration in seconds is set to '60'

.DESCRIPTION

    The minimum length in seconds of each lockout. If an account locks repeatedly, this duration increases.

    Queries settings
    and checks if values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value is set to '60'

.EXAMPLE
    Get-EidscaEIDSCA.PR05

    Returns the value of values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.PR05 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'LockoutDurationInSeconds' | select-object -expand value -eq '60') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
