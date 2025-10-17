<#
.SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset for administrators is set to 'false'

.DESCRIPTION

    Indicates whether administrators of the tenant can use the Self-Service Password Reset (SSPR). The policy applies to some critical critical roles in Microsoft Entra ID.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowedToUseSSPR -eq 'false'

.EXAMPLE
    Test-MtEidscaAP01

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToUseSSPR -eq 'false'
#>

function Test-MtEidscaAP01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $AuthorizationPolicyAvailable -notmatch 'allowedToUseSSPR' ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Settings value is not available. This may be due to the change that this API is no longer available for recent created tenants or tenants that are not licensed for Entra ID P1.'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    [string]$tenantValue = $result.allowedToUseSSPR
    $testResult = $tenantValue -eq 'false'
    $tenantValueNotSet = ($null -eq $tenantValue -or $tenantValue -eq "") -and 'false' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'false'** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Info'

    return $tenantValue
}
