<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Group owner consent for apps accessing data is set to 'False'

.DESCRIPTION

    Group and team owners can authorize applications, such as applications published by third-party vendors, to access your organization's data associated with a group. For example, a team owner in Microsoft Teams can allow an app to read all Teams messages in the team, or list the basic profile of a group's members.

    Queries settings
    and checks if values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value is set to 'False'

.EXAMPLE
    Get-EidscaEIDSCA.CP01

    Returns the value of values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.CP01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'EnableGroupSpecificConsent' | select-object -expand value -eq 'False') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
