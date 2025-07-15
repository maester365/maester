<#
.SYNOPSIS
    Checks state of spam filter

.DESCRIPTION
    Allowed domains SHALL NOT be added to inbound anti-spam protection policies.

.EXAMPLE
    Test-MtCisaSpamBypass

    Returns true if spam filter enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamBypass
#>
function Test-MtCisaSpamBypass {
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

    $resultPolicies = $policies | Where-Object { `
        $_.AllowedSenderDomains
    }

    $standard = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($resultPolicies|Measure-Object).Count -eq 0)

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

    $result += "| Policy Name | Policy Result | Allowed Domains |`n"
    $result += "| --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        if($item.Guid -notin $resultPolicies.Guid){
            $result += "| $($item.Identity) | $passResult | $($item.AllowedSenderDomains) |`n"
        }else{
            $result += "| $($item.Identity) | $failResult | $($item.AllowedSenderDomains) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%testResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}