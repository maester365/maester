<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Smart Lockout - Lockout threshold is set to '10'

.DESCRIPTION

    How many failed sign-ins are allowed on an account before its first lockout. If the first sign-in after a lockout also fails, the account locks out again.

    Queries settings
    and checks if values | where-object name -eq 'LockoutThreshold' | select-object -expand value is set to '10'

.EXAMPLE
    Get-EidscaEIDSCA.PR06

    Returns the value of values | where-object name -eq 'LockoutThreshold' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.PR06 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'LockoutThreshold' | select-object -expand value -eq '10') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
