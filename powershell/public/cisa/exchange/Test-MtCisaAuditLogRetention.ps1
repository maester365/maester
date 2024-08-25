<#
.SYNOPSIS
    Checks state of purview

.DESCRIPTION
    Audit logs SHALL be maintained for at least the minimum duration dictated by OMB M-21-31 (Appendix C).

.EXAMPLE
    Test-MtCisaAuditLogRetention

    Returns true if audit log retention enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAuditLogRetention
#>
function Test-MtCisaAuditLogRetention {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }elseif($null -eq (Get-MtLicenseInformation -Product AdvAudit)){
        Add-MtTestResultDetail -SkippedBecause NotLicensedAdvAudit
        return $null
    }

    $policies = Get-UnifiedAuditLogRetentionPolicy

    $resultPolicies = $policies | Where-Object { `
        $_.Enabled -and `
        $_.RecordTypes -contains "ExchangeAdmin" -and `
        $_.RecordTypes -contains "ExchangeItem" -and `
        $_.RecordTypes -contains "ExchangeItemGroup" -and `
        $_.RecordTypes -contains "ExchangeAggregatedOperation" -and `
        $_.RecordTypes -contains "ExchangeItemAggregated" -and `
        ($_.RetentionDuration -eq "TwelveMonths" -or `
        $_.RetentionDuration -like "*Years")
    }

    $testResult = ($resultPolicies|Measure-Object).Count -ge 1

    $portalLink = "https://purview.microsoft.com/audit/auditpolicies"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [Exchange Online audit retention enabled]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [Exchange Online audit retention enabled]($portalLink).`n`n%TestResult%"
    }

    $result = "| Policy Result | Policy Name | Record Types | Retention Duration |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach($item in $mailboxes | Sort-Object -Property Name){
        if($item.Guid -in $resultMailboxes.Guid){
            $result += "| $passResult | $($item.Name) | $($item.RecordTypes -join ", ") | $($item.RetentionDuration) |`n"
        }else{
            $result += "| $failResult | $($item.Name) | $($item.RecordTypes -join ", ") | $($item.RetentionDuration) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}