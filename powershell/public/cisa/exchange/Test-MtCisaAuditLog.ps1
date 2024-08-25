<#
.SYNOPSIS
    Checks state of purview

.DESCRIPTION
    Microsoft Purview Audit (Standard) logging SHALL be enabled.

.EXAMPLE
    Test-MtCisaAuditLog

    Returns true if audit log enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAuditLog
#>
function Test-MtCisaAuditLog {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }elseif(!(Test-MtConnection SecurityCompliance)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedSecurityCompliance
        return $null
    }

    $config = Get-AdminAuditLogConfig

    $testResult = $config.UnifiedAuditLogIngestionEnabled

    $portalLink = "https://purview.microsoft.com/audit/auditsearch"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [unified audit log enabled]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have [unified audit log enabled]($portalLink).`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}