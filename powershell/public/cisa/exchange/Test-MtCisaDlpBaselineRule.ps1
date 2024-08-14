<#
.SYNOPSIS
    Checks state of baseline CISA rules for DLP in EXO

.DESCRIPTION
    At a minimum, the DLP solution SHALL restrict sharing credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN) via email.

.EXAMPLE
    Test-MtCisaDlpBaselineRule

    Returns true if baseline rules are enforced

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDlpBaselineRule
#>
function Test-MtCisaDlpBaselineRule {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }elseif($null -eq (Get-MtLicenseInformation -Product ExoDlp)){
        Add-MtTestResultDetail -SkippedBecause NotLicensedExoDlp
        return $null
    }

    $policies = Get-MtExo -Request DlpCompliancePolicy

    $resultPolicies = $policies | Where-Object {`
        $_.ExchangeLocation.DisplayName -contains "All" -and `
        $_.Workload -like "*Exchange*" -and `
        -not $_.IsSimulationPolicy -and `
        $_.Enabled
    }

    $rules = $resultPolicies | ForEach-Object {
        Get-MtExo -Request DlpComplianceRule
    }

    $sits = [pscustomobject]@{
        ccn  = "*50842eb7-edc8-4019-85dd-5a5c1f2bb085*" # Credit Card Number
        ssn  = "*a44669fe-0d48-453d-a9b1-2cc83f2cba77*" # U.S. Social Security Number (SSN)
        itin = "*e55e2a32-f92d-4985-a35d-a0b269eb687b*" # U.S. Individual Taxpayer Identification Number (ITIN)
    }

    $resultRules = $rules | Where-Object {`
        -not $_.Disabled -and `
        $_.Mode -eq "Enforce" -and `
        $_.BlockAccess -and `
        $_.BlockAccessScope -eq "All" -and `
        $_.NotifyPolicyTipDisplayOption -eq "Tip" -and (`
            $_.AdvancedRule -like $sits.ccn -or`
            $_.AdvancedRule -like $sits.ssn -or`
            $_.AdvancedRule -like $sits.itin
        )
    }

    $resultCcn  = $resultRules.AdvancedRule -join "`n" -like $sits.ccn
    $resultSsn  = $resultRules.AdvancedRule -join "`n" -like $sits.ssn
    $resultItin = $resultRules.AdvancedRule -join "`n" -like $sits.itin

    $resultComposite = $resultCcn -and $resultSsn -and $resultItin

    $testResult = ($resultComposite | Measure-Object).Count -ge 1

    $portalLink = "https://purview.microsoft.com/datalossprevention/policies"

    if ($resultComposite) {
        $testResultMarkdown = "Well done. Your tenant has [Purview Data Loss Prevention Policies]($portalLink) enabled with the Sensitive Info Type of credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [Purview Data Loss Prevention Policies]($portalLink) enabled with the Sensitive Info Type of credit card numbers, U.S. Individual Taxpayer Identification Numbers (ITIN), and U.S. Social Security numbers (SSN).`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "Required Rules:`n`n"
    $result += "| Credit Card Number | U.S. Social Security Number | U.S. Individual Taxpayer Identification Number |`n"
    $result += "| --- | --- | --- |`n"
    $result += "| $(if($resultCcn){$passResult}else{$failResult}) | $(if($resultSsn){$passResult}else{$failResult}) | $(if($resultItin){$passResult}else{$failResult}) |`n`n"
    $result += "Rule Relationships:`n`n"
    $result += "| Status | Policy | Rule |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in ($rules | Sort-Object -Property ParentPolicyName,Name)) {
        $itemResult = $failResult
        if($item.Guid -in $resultRules.Guid){
            $itemResult = $passResult
        }
        $result += "| $($itemResult) | $($item.ParentPolicyName) | $($item.Name) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}