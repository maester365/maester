<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Mode is set to 'Enforce'

.DESCRIPTION

    If set to Enforce, users will be prevented from setting banned passwords and the attempt will be logged. If set to Audit, the attempt will only be logged.

    Queries settings
    and checks if values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value is set to 'Enforce'

.EXAMPLE
    Get-EidscaEIDSCA.PR01

    Returns the value of values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.PR01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
