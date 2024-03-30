<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Report suspicious activity - Included users/groups is set to 'all_users'

.DESCRIPTION

    Object Id or scope of users which will be included to report suspicious activities if they receive an authentication request that they did not initiate.

    Queries policies/authenticationMethodsPolicy
    and returns the result of
     graph/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'

.EXAMPLE
    Test-EidscaAG03

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'
#>

Function Test-EidscaAG03 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    $testResult = $result.reportSuspiciousActivitySettings.includeTarget.id -eq 'all_users'

    Add-MtTestResultDetail -Result $testResult
}
