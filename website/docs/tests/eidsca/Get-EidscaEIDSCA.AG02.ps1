<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - State is set to 'enabled'

.DESCRIPTION

    Allows users to report suspicious activities if they receive an authentication request that they did not initiate. This control is available when using the Microsoft Authenticator app and voice calls. Reporting suspicious activity will set the user's risk to high. If the user is subject to risk-based Conditional Access policies, they may be blocked.

    Queries policies/authenticationMethodsPolicy
    and checks if reportSuspiciousActivitySettings.state is set to 'enabled'

.EXAMPLE
    Get-EidscaEIDSCA.AG02

    Returns the value of reportSuspiciousActivitySettings.state at policies/authenticationMethodsPolicy
#>

Function Get-EidscaEIDSCA.AG02 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    if($result.reportSuspiciousActivitySettings.state -eq 'enabled') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
