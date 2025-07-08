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

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA on March 2025. MS.EXO.17.2v1 was originally included in order to enable auditing of additional user actions not captured under Purview Audit (Standard). In October 2023, Microsoft announced changes to its Purview Audit service that included making audit events in Purview Audit (Premium) available to Purview Audit (Standard) subscribers. Now that the rollout of changes has been completed, Purview (Standard) includes the necessary auditing which is addressed by MS.EXO.17.2v1 See [CISA Gov - GitHub](https://github.com/cisagov/ScubaGear/blob/7cefa12639b4bc36990f8f2849b57ad2fdafec4c/PowerShell/ScubaGear/baselines/removedpolicies.md?plain=1#L56)"
    return $null

    # if(!(Test-MtConnection ExchangeOnline)){
    #     Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
    #     return $null
    # }elseif(!(Test-MtConnection SecurityCompliance)){
    #     Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
    #     return $null
    # }elseif($null -eq (Get-MtLicenseInformation -Product AdvAudit)){
    #     Add-MtTestResultDetail -SkippedBecause NotLicensedAdvAudit
    #     return $null
    # }

    # Write-Verbose "In tenants with a substantial number of mailboxes this test may take time"
    # $mailboxes = Get-EXOMailbox -Properties AuditOwner

    # $resultMailboxes = $mailboxes | Where-Object { `
    #     $_.AuditOwner -notcontains "SearchQueryInitiated"
    # }

    # $testResult = ($resultMailboxes|Measure-Object).Count -ge 1

    # $portalLink = "https://purview.microsoft.com/audit/auditsearch"
    # $passResult = "✅ Pass"
    # $failResult = "❌ Fail"

    # if ($testResult) {
    #     $testResultMarkdown = "Well done. Your tenant has [SearchQueryInitiated audit log enabled]($portalLink).`n`n%TestResult%"
    # } else {
    #     $testResultMarkdown = "Your tenant does not have [SearchQueryInitiated audit log enabled]($portalLink).`n`n%TestResult%"
    # }

    # $result = "| Mailbox | SearchQueryInitiated |`n"
    # $result += "| --- | --- |`n"
    # foreach($item in $mailboxes | Sort-Object -Property UserPrincipalName){
    #     if($item.Guid -notin $resultMailboxes.Guid){
    #         $result += "| $($item.UserPrincipalName) | $($passResult) |`n"
    #     }else{
    #         $result += "| $($item.UserPrincipalName) | $($failResult) |`n"
    #     }
    # }

    # $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    # Add-MtTestResultDetail -Result $testResultMarkdown

    # return $testResult
}