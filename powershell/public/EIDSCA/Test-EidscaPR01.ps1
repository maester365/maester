<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Mode is set to 'Enforce'

.DESCRIPTION

    If set to Enforce, users will be prevented from setting banned passwords and the attempt will be logged. If set to Audit, the attempt will only be logged.

    Queries settings
    and returns the result of
     graph/settings.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce'

.EXAMPLE
    Test-EidscaPR01

    Returns the result of graph.microsoft.com/beta/settings.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce'
#>

Function Test-EidscaPR01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    $testResult = $result.values | where-object name -eq 'BannedPasswordCheckOnPremisesMode' | select-object -expand value -eq 'Enforce'

    Add-MtTestResultDetail -Result $testResult
}
