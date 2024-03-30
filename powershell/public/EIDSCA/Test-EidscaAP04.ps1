<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest invite restrictions is set to 'adminsAndGuestInviters'

.DESCRIPTION

    Manages controls who can invite guests to your directory to collaborate on resources secured by your Azure AD, such as SharePoint sites or Azure resources.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowInvitesFrom -eq 'adminsAndGuestInviters'

.EXAMPLE
    Test-EidscaAP04

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowInvitesFrom -eq 'adminsAndGuestInviters'
#>

Function Test-EidscaAP04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.allowInvitesFrom -eq 'adminsAndGuestInviters'

    Add-MtTestResultDetail -Result $testResult
}
