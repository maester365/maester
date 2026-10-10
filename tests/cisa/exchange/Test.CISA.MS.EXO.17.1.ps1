function Test-MtCisaAuditLog {
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
    [MaesterTest(
        Id = 'CISA.MS.EXO.17.1',
        Title = 'Microsoft Purview Audit (Standard) logging SHALL be enabled.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.17.1'),
        Service = ('ExchangeOnline', 'SecurityCompliance'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-AdminAuditLogConfig

    $testResult = $config.UnifiedAuditLogIngestionEnabled

    $portalLink = "https://purview.microsoft.com/audit/auditsearch"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [unified audit log enabled]($portalLink)."
    } else {
        $testResultMarkdown = "Your tenant does not have [unified audit log enabled]($portalLink)."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
