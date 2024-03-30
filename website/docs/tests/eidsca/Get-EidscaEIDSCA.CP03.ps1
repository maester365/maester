<#
.SYNOPSIS
    Checks if Default Settings - Consent Policy Settings - Block user consent for risky apps is set to 'true'

.DESCRIPTION

    Defines whether user consent will be blocked when a risky request is detected

    Queries settings
    and checks if values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.CP03

    Returns the value of values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value at settings
#>

Function Get-EidscaEIDSCA.CP03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "settings" -ApiVersion beta

    if($result.values | where-object name -eq 'BlockUserConsentForRiskyApps' | select-object -expand value -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
