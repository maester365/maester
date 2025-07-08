<#
.SYNOPSIS
    Checks if audit log search is enabled

.DESCRIPTION
    Microsoft 365 audit log search should be enabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisAuditLogSearch

    Returns true if audit log search is enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisAuditLogSearch
#>
function Test-MtCisAuditLogSearch {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose 'Get audit log search status'
        $auditLogSearch = Get-AdminAuditLogConfig

        Write-Verbose 'Check audit log search is enabled'
        $result = $auditLogSearch | Where-Object { $_.UnifiedAuditLogIngestionEnabled -ne 'True' }

        $testResult = ($result | Measure-Object).Count -eq 0

        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant has audit log search enabled:`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant does not have audit log search enabled:`n`n%TestResult%"
        }

        $resultMd = "| Audit Log Search |`n"
        $resultMd += "| --- |`n"
        foreach ($item in $auditLogSearch) {
            $itemResult = '❌ Fail'
            if ($item.id -notin $result.id) {
                $itemResult = '✅ Pass'
            }
            $resultMd += "| $($itemResult) |`n"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
