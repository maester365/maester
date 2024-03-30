<#
.SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner is set to 'false'

.DESCRIPTION

    Indicating whether or not a guest user can be an owner of groups

    Queries settings
    and checks if values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value is set to 'false'

.EXAMPLE
    Get-EidscaEIDSCA.ST08

    Returns the value of values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.ST08 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
