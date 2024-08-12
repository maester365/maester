<#
.SYNOPSIS
    Checks state of preset security policies

.DESCRIPTION
    Emails SHALL be filtered by attachment file types

.EXAMPLE
    Test-MtCisaPresetSecurity

    Returns true if standard and strict protection is on

.LINK
    https://maester.dev/docs/commands/Test-MtCisaPresetSecurity
#>
function Test-MtCisaPresetSecurity {
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

    $policies = Get-MtATPProtectionPolicyRule

    $standard = $policies | Where-Object { `
        $_.State -eq "Enabled" -and
        $_.Identity -eq "Standard Preset Security Policy"
    }

    $strict = $policies | Where-Object { `
        $_.State -eq "Enabled" -and
        $_.Identity -eq "Strict Preset Security Policy"
    }

    $testResult = $standard -and $strict

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [standard and strict preset security policies enabled]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [standard and strict preset security policies enabled]($portalLink).`n`n%TestResult%"
    }

    $result = "| Policy | Status |`n"
    $result += "| --- | --- |`n"
    if($standard){
        $result += "| Standard | $passResult |`n"
    }else{
        $result += "| Standard | $failResult |`n"
    }
    if($strict){
        $result += "| Strict | $passResult |`n"
    }else{
        $result += "| Strict | $failResult |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}