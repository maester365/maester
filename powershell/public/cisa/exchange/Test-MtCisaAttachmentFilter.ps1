<#
.SYNOPSIS
    Checks state of preset security policies

.DESCRIPTION
    Emails SHALL be filtered by attachment file types
    Emails SHALL be scanned for malware.

.EXAMPLE
    Test-MtCisaAttachmentFilter

    Returns true if standard and strict protection is on

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAttachmentFilter
#>
function Test-MtCisaAttachmentFilter {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $policies = Get-MtExoThreatPolicyMalware

    $failingPolicies = $policies | Where-Object { $_.IsEnabled -and -not $_.EnableFileFilter }
    $testResult = ($failingPolicies | Measure-Object).Count -eq 0

    $portalLink = "https://security.microsoft.com/antimalwarev2"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"

    $result = "| Policy name | Enabled | EnableFileFilter | Extensions | Result |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($item in $policies) {
        if ($item.FileTypes) {
            $resultFilesList = ($item.FileTypes | Select-Object -First 5) -join ", "
            $resultFilesList += ", & $(($item.FileTypes|Measure-Object).Count -5) others"
        } else {
            $resultFilesList = ""
        }
        if (-not $item.IsEnabled) {
            $result += "| $($item.Identity) | $false | $($item.EnableFileFilter) | $resultFilesList | $($skipResult) |`n"
        } elseif ($item.EnableFileFilter) {
            $result += "| $($item.Identity) | $true | $($item.EnableFileFilter) | $resultFilesList | $($passResult) |`n"
        } else {
            $result += "| $($item.Identity) | $true | $($item.EnableFileFilter) | $resultFilesList | $($failResult) |`n"
        }
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. All the anti-malware policies in your tenant has the common attachments filter enabled ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have all the anti-malware policies with the common attachments filter enabled ($portalLink).`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}