function Test-MtCisAuditLogSearch {
    <#
    .SYNOPSIS
    Checks if audit log search is enabled

    .DESCRIPTION
    Microsoft 365 audit log search should be enabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.1.1, L1)

    .EXAMPLE
    Test-MtCisAuditLogSearch

    Returns true if audit log search is enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisAuditLogSearch
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.1.1',
        Title = 'Ensure Microsoft 365 audit log search is Enabled',
        Severity = 'High',
        Category = 'CIS',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Get audit log search status'
    $auditLogSearch = Get-AdminAuditLogConfig

    if ($auditLogSearch | Where-Object { $_.UnifiedAuditLogIngestionEnabled -ne 'True' }) {
        $testResult = $false
        $testResultMarkdown = "Your tenant does not have audit log search enabled:`n`n%TestResult%"
    } else {
        $testResult = $true
        $testResultMarkdown = "Well done. Your tenant has audit log search enabled:`n`n%TestResult%"
    }

    $resultMd = "| Audit Log | Status |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $auditLogSearch) {
        if ($item.UnifiedAuditLogIngestionEnabled) {
            $itemResult = '✅ Enabled'
        } else {
            $itemResult = '❌ Disabled'
        }
        $resultMd += "| $($item.Name) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
