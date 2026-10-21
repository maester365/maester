function Test-MtEidscaCR05 {
    <#
    .SYNOPSIS
    Checks if Consent Framework - Admin Consent Request - Admin consent reviewers have valid query scopes is set to 'true'

    .DESCRIPTION

    Checks that the enabled admin consent workflow has at least one reviewer scope and that every scope has a MicrosoftGraph query with a structurally valid absolute or rooted relative path. A null queryRoot is valid for absolute paths. This structural check does not execute queries, resolve membership, or establish reviewer availability or approval permissions.

    Queries policies/adminConsentRequestPolicy
    and returns the tenant value of
    graph/policies/adminConsentRequestPolicy.reviewers.Count -gt 0 -and @($result.reviewers

    The native test EIDSCA.CR05 passes when this value -eq 'true'.

    .EXAMPLE
    Test-MtEidscaCR05

    Returns the tenant value of graph.microsoft.com/beta/policies/adminConsentRequestPolicy.reviewers.Count -gt 0 -and @($result.reviewers
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/adminConsentRequestPolicy" -ApiVersion beta

    $rawValue = $result.reviewers.Count -gt 0 -and @($result.reviewers | Where-Object { $null -eq $_ -or $_.queryType -ne 'MicrosoftGraph' -or [string]::IsNullOrWhiteSpace($_.query) -or ($_.query -notmatch '^/(?!/)\S' -and ($_.query -notmatch '^\./\S' -or $_.queryRoot -ne 'decisions')) }).Count -eq 0
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
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Low'

    return $tenantValue
}
