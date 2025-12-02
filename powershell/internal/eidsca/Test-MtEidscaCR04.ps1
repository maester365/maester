<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Consent request duration (days) is set to 30

.DESCRIPTION

    Specifies the duration the request is active before it automatically expires if no decision is applied

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.requestDurationInDays -le 30

.EXAMPLE
    Test-MtEidscaCR04

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.requestDurationInDays -le 30
#>

function Test-MtEidscaCR04 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( $EnabledAdminConsentWorkflow -eq $false ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Admin Consent Workflow is not enabled'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    [int]$tenantValue = $result.requestDurationInDays
    $testResult = $tenantValue -le 30
    $tenantValueNotSet = $null -eq $tenantValue -and 30 -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is less than or equal to **30** for **policies/adminConsentRequestPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **30** for **policies/adminConsentRequestPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is less than or equal to **30** for **policies/adminConsentRequestPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity ''

    return $tenantValue
}
