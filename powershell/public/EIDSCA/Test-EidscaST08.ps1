<#
.SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner is set to 'false'

.DESCRIPTION

    Indicating whether or not a guest user can be an owner of groups

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'

.EXAMPLE
    Test-EidscaST08

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'
#>

Function Test-EidscaST08 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $testResult = $result.values | where-object name -eq 'AllowGuestsToBeGroupOwner' | select-object -expand value -eq 'false'

    Add-MtTestResultDetail -Result $testResult
}
