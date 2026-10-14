function Test-MtEidscaCR02 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Reviewers will receive email notifications for requests is set to 'true'

    .DESCRIPTION

    Specifies whether reviewers will receive notifications

    Queries policies/adminConsentRequestPolicy
    and returns the tenant value of
    graph/policies/adminConsentRequestPolicy.notifyReviewers

    The native test EIDSCA.CR02 passes when this value -eq 'true'.

    .EXAMPLE
    Test-MtEidscaCR02

    Returns the tenant value of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.notifyReviewers
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $rawValue = $result.notifyReviewers
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'true'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'true' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'true'** for **policies/adminConsentRequestPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'true'** for **policies/adminConsentRequestPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity ''

    return $tenantValue
}
