<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - Included users/groups is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.

    Queries policies/authenticationMethodsPolicy
    and checks if reportSuspiciousActivitySettings.includeTarget.id is set to 'all_users'

.EXAMPLE
    Get-EidscaEIDSCA.AG03

    Returns the value of reportSuspiciousActivitySettings.includeTarget.id at policies/authenticationMethodsPolicy
#>

Function Get-EidscaEIDSCA.AG03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    if($result.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
