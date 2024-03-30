<#
.SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content is set to 'True'

.DESCRIPTION

    Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

    Queries settings
    and checks if values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value is set to 'True'

.EXAMPLE
    Get-EidscaEIDSCA.ST09

    Returns the value of values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.ST09 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'AllowGuestsToAccessGroups' | select-object -expand value -eq 'True') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
