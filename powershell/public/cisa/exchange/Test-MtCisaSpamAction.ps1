<#
.SYNOPSIS
    Checks state of spam filter

.DESCRIPTION
    Spam and high confidence spam SHALL be moved to either the junk email folder or the quarantine folder.

.EXAMPLE
    Test-MtCisaSpamAction

    Returns true if spam filter enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamAction
#>
function Test-MtCisaSpamAction {
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

    $policies = Get-MtExo -Request HostedContentFilterPolicy

    $resultPolicies = $policies | Where-Object { `
        $_.SpamAction -in @("MoveToJmf","Quarantine") -and `
        $_.HighConfidenceSpamAction -in @("MoveToJmf","Quarantine")
    }

    $standard = $resultPolicies | Where-Object { `
        $_.RecommendedPolicyType -eq "Standard"
    }

    $strict = $resultPolicies | Where-Object { `
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

    $result += "| Policy Name | Spam Action | High Confidence Spam Action |`n"
    $result += "| --- | --- | --- |`n"
    foreach($item in $policies | Sort-Object -Property Identity){
        if($item.SpamAction -in @("MoveToJmf","Quarantine")){
            $resultSpamAction = $passResult
        }else{
            $resultSpamAction = $failResult
        }
        if($item.HighConfidenceSpamAction -in @("MoveToJmf","Quarantine")){
            $resultHighConfidenceSpamAction = $passResult
        }else{
            $resultHighConfidenceSpamAction = $failResult
        }
        $result += "| $($item.Identity) | $resultSpamAction | $resultHighConfidenceSpamAction |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}