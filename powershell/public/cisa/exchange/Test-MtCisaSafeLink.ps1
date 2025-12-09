<#
.SYNOPSIS
    Checks state of URL block list

.DESCRIPTION
    URL comparison with a block-list SHOULD be enabled.

.EXAMPLE
    Test-MtCisaSafeLink

    Returns true if URL block list enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeLink
#>
function Test-MtCisaSafeLink {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif ('P1' -notin (Get-MtLicenseInformation -Product MdoV2)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdoP1
        return $null
    }

    $policies = Get-MtExo -Request SafeLinksPolicy

    $resultPolicies = $policies | Where-Object { `
            $_.EnableSafeLinksForEmail
    }

    $standard = $policies | Where-Object { `
            $_.RecommendedPolicyType -eq 'Standard'
    }

    $strict = $policies | Where-Object { `
            $_.RecommendedPolicyType -eq 'Strict'
    }

    $testResult = $standard -and $strict -and (($resultPolicies | Measure-Object).Count -ge 1)

    $portalLink = 'https://security.microsoft.com/presetSecurityPolicies'
    $passResult = '✅ Pass'
    $failResult = '❌ Fail'

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [standard and strict preset security policies]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [standard and strict preset security policies]($portalLink).`n`n%TestResult%"
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

    $result += "| Policy Name | Policy Result |`n"
    $result += "| --- | --- |`n"
    foreach ($item in $policies | Sort-Object -Property Identity) {
        if ($item.Guid -in $resultPolicies.Guid) {
            $result += "| $($item.Identity) | $passResult |`n"
        } else {
            $result += "| $($item.Identity) | $failResult |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}