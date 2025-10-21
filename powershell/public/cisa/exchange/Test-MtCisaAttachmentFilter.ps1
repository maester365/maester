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

    # $fileFilter = $policies | Where-Object { `
    #     $_.EnableFileFilter
    # }

    # $standard = $policies | Where-Object { `
    #     $_.RecommendedPolicyType -eq "Standard"
    # }

    # $strict = $policies | Where-Object { `
    #     $_.RecommendedPolicyType -eq "Strict"
    # }

    # $testResult = $standard -and $strict -and (($fileFilter|Measure-Object).Count -ge 1)

    # $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    # $passResult = "✅ Pass"
    # $failResult = "❌ Fail"

    # if ($testResult) {
    #     $testResultMarkdown = "Well done. Your tenant has [standard and strict preset security policies for the common file filter]($portalLink).`n`n%TestResult%"
    # } else {
    #     $testResultMarkdown = "Your tenant does not have [standard and strict preset security policies enabled]($portalLink).`n`n%TestResult%"
    # }

    # $result = "| Policy | Status |`n"
    # $result += "| --- | --- |`n"
    # if ($standard) {
    #     $result += "| Standard | $passResult |`n"
    # } else {
    #     $result += "| Standard | $failResult |`n"
    # }
    # if ($strict) {
    #     $result += "| Strict | $passResult |`n`n"
    # } else {
    #     $result += "| Strict | $failResult |`n`n"
    # }

    # $result += "| Policy Name | File Filter Enabled | Extensions |`n"
    # $result += "| --- | --- | --- |`n"
    # foreach($item in $policies | Sort-Object -Property Identity){
    #     if($item.EnableFileFilter){
    #         $resultFilesList = ($item.FileTypes | Select-Object -First 5) -join ", "
    #         $resultFilesList += ", & $(($item.FileTypes|Measure-Object).Count -5) others"
    #         $result += "| $($item.Identity) | $($passResult) | $resultFilesList |`n"
    #     }else{
    #         $result += "| $($item.Identity) | $($failResult) |  |`n"
    #     }
    # }

    # $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    # Add-MtTestResultDetail -Result $testResultMarkdown

    # return $testResult
}