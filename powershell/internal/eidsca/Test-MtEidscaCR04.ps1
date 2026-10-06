function Test-MtEidscaCR04 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Consent request duration (days) is set to 30

    .DESCRIPTION

    Specifies the duration the request is active before it automatically expires if no decision is applied

    Queries policies/adminConsentRequestPolicy
    and returns the tenant value of
    graph/policies/adminConsentRequestPolicy.requestDurationInDays

    The native test EIDSCA.CR04 passes when this value -le 30.

    .EXAMPLE
    Test-MtEidscaCR04

    Returns the tenant value of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.requestDurationInDays
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $rawValue = $result.requestDurationInDays
    [int]$tenantValue = $rawValue
    $testResult = $tenantValue -le 30
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 30 -notlike '*$null*'

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
