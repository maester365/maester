<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest invite restrictions is set to 'adminsAndGuestInviters'

.DESCRIPTION

    Manages controls who can invite guests to your directory to collaborate on resources secured by your Azure AD, such as SharePoint sites or Azure resources.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowInvitesFrom -eq 'adminsAndGuestInviters'

.EXAMPLE
    Test-MtEidscaAP04

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowInvitesFrom -eq 'adminsAndGuestInviters'
#>

Function Test-MtEidscaAP04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    [string]$tenantValue = $result.allowInvitesFrom
    $testResult = $tenantValue -eq 'adminsAndGuestInviters'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'adminsAndGuestInviters'** for **policies/authorizationPolicy**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'adminsAndGuestInviters'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
