<#
.SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications when admin consent requests are about to expire is set to 'true'

.DESCRIPTION

    Specifies whether reviewers will receive reminder emails

    Queries policies/adminConsentRequestPolicy
    and returns the result of
     graph/policies/adminConsentRequestPolicy.remindersEnabled -eq 'true'

.EXAMPLE
    Test-MtEidscaCR03

    Returns the result of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.remindersEnabled -eq 'true'
#>

function Test-MtEidscaCR03 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ( ($EnabledAdminConsentWorkflow) -eq $false ) {
            Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'Admin Consent Workflow is not enabled'
            return $null
    }
    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    [string]$tenantValue = $result.remindersEnabled
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = $null -eq $tenantValue -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **policies/adminConsentRequestPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
