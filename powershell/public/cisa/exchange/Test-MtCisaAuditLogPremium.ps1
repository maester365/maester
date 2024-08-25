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

    Write-Warning "In tenants with a substantial number of mailboxes this test may take time"
    $mailboxes = Get-EXOMailbox -Properties AuditOwner

    $resultMailboxes = $mailboxes | Where-Object { `
        $_.AuditOwner -notcontains "SearchQueryInitiated"
    }

    $testResult = ($resultMailboxes|Measure-Object).Count -ge 1

    $portalLink = "https://purview.microsoft.com/audit/auditsearch"
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [SearchQueryInitiated audit log enabled]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [SearchQueryInitiated audit log enabled]($portalLink).`n`n%TestResult%"
    }

    $result = "| Mailbox | SearchQueryInitiated |`n"
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