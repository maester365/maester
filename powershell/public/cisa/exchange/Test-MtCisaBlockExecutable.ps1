<#
.SYNOPSIS
    Checks state of preset security policies

.DESCRIPTION
    Emails SHALL be filtered by attachment file types

.EXAMPLE
    Test-MtCisaBlockExecutable

    Returns true if standard and strict protection is on

.LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockExecutable
#>
function Test-MtCisaBlockExecutable {
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

    $clickToRunExtensions = @(
        "cmd",
        "exe",
        "vbe"
    )

    $resultPolicies = @()
    foreach($policy in $policies){
        $p = [PSCustomObject]@{
            Identity              = $policy.Identity
            EnableFileFilter      = $policy.EnableFileFilter
            RecommendedPolicyType = $policy.RecommendedPolicyType
            clickToRunExtensions  = @()
        }
        foreach($extension in $clickToRunExtensions){
            if($extension -in $policy.FileTypes){
                $p.clickToRunExtensions += $extension
            }
        }
        $resultPolicies += $p
    }

    $fileFilter = $resultPolicies | Where-Object { `
        $_.EnableFileFilter -and `
        ($_.clickToRunExtensions|Measure-Object).Count -eq ($clickToRunExtensions|Measure-Object).Count
    }

    $standard = $resultPolicies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $resultPolicies | Where-Object { `
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
    foreach($item in $resultPolicies | Sort-Object -Property Identity){
        if($item.EnableFileFilter){
            $resultFilesList = ($item.clickToRunExtensions) -join ", "
            $result += "| $($item.Identity) | $($passResult) | $resultFilesList |`n"
        }else{
            $result += "| $($item.Identity) | $($failResult) |  |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}