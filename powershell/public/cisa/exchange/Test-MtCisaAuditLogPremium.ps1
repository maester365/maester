<#
.SYNOPSIS
    Checks state of purview

.DESCRIPTION
    Microsoft Purview Audit (Premium) logging SHALL be enabled.

.EXAMPLE
    Test-MtCisaAuditLogPremium

    Returns true if audit log enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAuditLogPremium
#>
function Test-MtCisaAuditLogPremium {
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

    Write-Verbose "In tenants with a substantial number of mailboxes this test may take time"
    $mailboxes = Get-EXOMailbox -ResultSize Unlimited -PropertySets Audit

    $resultMailboxes = $mailboxes | Where-Object { `
        $_.AuditOwner -notcontains "SearchQueryInitiated"
    }

    $testResult = ($resultMailboxes|Measure-Object).Count -eq 0

    $portalLink = "https://purview.microsoft.com/audit/auditsearch"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [SearchQueryInitiated audit log]($portalLink) enabled for all users.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [SearchQueryInitiated audit log]($portalLink) enabled for all users.`n`n%TestResult%"
    }

    $result = "$passResult ($(($mailboxes.count - $resultMailboxes.count)) of $($mailboxes.count)) $failResult ($($resultMailboxes.count) of $($mailboxes.count)). Showing first 100.`n`n"
    $result += "| Mailbox | SearchQueryInitiated |`n"
    $result += "| --- | --- |`n"
    foreach($item in $mailboxes | Sort-Object -Property UserPrincipalName){
        if($item.Guid -notin $resultMailboxes.Guid){
            $result += "| $($item.UserPrincipalName) | $($passResult) |`n"
        }else{
            $result += "| $($item.UserPrincipalName) | $($failResult) |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}