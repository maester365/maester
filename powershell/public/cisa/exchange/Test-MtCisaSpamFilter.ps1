<#
.SYNOPSIS
    Checks state of spam filter

.DESCRIPTION
    A spam filter SHALL be enabled.

.EXAMPLE
    Test-MtCisaSpamFilter

    Returns true if spam filter enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamFilter
#>
function Test-MtCisaSpamFilter {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    $policies = Get-MtExo -Request HostedContentFilterPolicy

    $standard = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($policies|Measure-Object).Count -ge 1)

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [standard and strict preset security policies]($portalLink).`n`n%testResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [standard and strict preset security policies]($portalLink).`n`n%testResult%"
    }

    $result = "| Policy | Status |`n"
    $result += "| --- | --- |`n"
    if ($standard) {
        $result += "| Standard | $passResult |`n"
    } else {
        $result += "| Standard | $failResult |`n"
    }
    if ($strict) {
        $result += "| Strict | $passResult |`n`n"
    } else {
        $result += "| Strict | $failResult |`n`n"
    }

    $result += "| Policy Name | Spam Action | High Confidence Spam Action | Bulk Spam Action | Phish Spam Action |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        $result += "| $($item.Identity) | $($item.SpamAction) | $($item.HighConfidenceSpamAction) | $($item.BulkSpamAction) | $($item.PhishSpamAction) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%testResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}