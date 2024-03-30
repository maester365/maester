<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest invite restrictions is set to 'adminsAndGuestInviters'

.DESCRIPTION

    Manages controls who can invite guests to your directory to collaborate on resources secured by your Azure AD, such as SharePoint sites or Azure resources.

    Queries policies/authorizationPolicy
    and checks if allowInvitesFrom is set to 'adminsAndGuestInviters'

.EXAMPLE
    Get-EidscaEIDSCA.AP04

    Returns the value of allowInvitesFrom at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP04 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.allowInvitesFrom -eq 'adminsAndGuestInviters') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
