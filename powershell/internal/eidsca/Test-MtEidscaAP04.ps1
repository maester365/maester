<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest invite restrictions is set to @('adminsAndGuestInviters','none')

.DESCRIPTION

    Manages controls who can invite guests to your directory to collaborate on resources secured by your Azure AD, such as SharePoint sites or Azure resources.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowInvitesFrom -in @('adminsAndGuestInviters','none')

.EXAMPLE
    Test-MtEidscaAP04

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowInvitesFrom -in @('adminsAndGuestInviters','none')
#>

function Test-MtEidscaAP04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    [string]$tenantValue = $result.allowInvitesFrom
    $testResult = $tenantValue -in @('adminsAndGuestInviters','none')
    $tenantValueNotSet = $null -eq $tenantValue -and @('adminsAndGuestInviters','none') -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is one of the following values **@('adminsAndGuestInviters','none')** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **@('adminsAndGuestInviters','none')** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is one of the following values **@('adminsAndGuestInviters','none')** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
