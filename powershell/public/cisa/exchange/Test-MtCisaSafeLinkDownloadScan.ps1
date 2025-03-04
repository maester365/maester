<#
.SYNOPSIS
    Checks state of URL direct download scans

.DESCRIPTION
    Direct download links SHOULD be scanned for malware.

.EXAMPLE
    Test-MtCisaSafeLinkDownloadScan

    Returns true if URL direct download scan enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeLinkDownloadScan
#>
function Test-MtCisaSafeLinkDownloadScan {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }elseif($null -eq (Get-MtLicenseInformation -Product Mdo)){
        Add-MtTestResultDetail -SkippedBecause NotLicensedMdo
        return $null
    }

    $policies = Get-MtExo -Request SafeLinksPolicy

    $resultPolicies = $policies | Where-Object { `
        $_.ScanUrls
    }

    $standard = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $policies | Where-Object { `
        $_.RecommendedPolicyType -eq "Strict"
    }

    $testResult = $standard -and $strict -and (($resultPolicies|Measure-Object).Count -ge 1)

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

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
    foreach($item in $policies | Sort-Object -Property Identity){
        if($item.Guid -in $resultPolicies.Guid){
            $result += "| $($item.Identity) | $passResult |`n"
        }else{
            $result += "| $($item.Identity) | $failResult |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}