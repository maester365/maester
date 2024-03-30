<#
.SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Enable password protection on Windows Server Active Directory is set to 'True'

.DESCRIPTION

    If set to Yes, password protection is turned on for Active Directory domain controllers when the appropriate agent is installed.

    Queries settings
    and checks if values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value is set to 'True'

.EXAMPLE
    Get-EidscaEIDSCA.PR02

    Returns the value of values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.PR02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'EnableBannedPasswordCheckOnPremises' | select-object -expand value -eq 'True') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
