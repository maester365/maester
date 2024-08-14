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
    } elseif (!(Test-MtConnection SecurityCompliance)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    } elseif ($null -eq (Get-MtLicenseInformation -Product Mdo)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }

    $policies = Get-MtExo -Request MalwareFilterPolicy

    $fileFilter = $policies | Where-Object { `
        $_.EnableFileFilter
    }

    $standard = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($fileFilter|Measure-Object).Count -ge 1)

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [standard and strict preset security policies for the common file filter]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [standard and strict preset security policies enabled]($portalLink).`n`n%TestResult%"
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

    $result += "| Policy Name | File Filter Enabled | Extensions |`n"
    $result += "| --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        if($item.EnableFileFilter){
            $resultFilesList = ($item.FileTypes | Select-Object -First 5) -join ", "
            $resultFilesList += ", & $(($item.FileTypes|Measure-Object).Count -5) others"
            $result += "| $($item.Identity) | $($passResult) | $resultFilesList |`n"
        }else{
            $result += "| $($item.Identity) | $($failResult) |  |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}