function Test-MtCisaAuditLogRetention {
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
    [MaesterTest(
        Id = 'CISA.MS.EXO.17.3',
        Title = 'Audit logs SHALL be maintained for at least the minimum duration dictated by OMB M-21-31 (Appendix C).',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.17.3'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        License = 'M365_ADVANCED_AUDITING',
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

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

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [Exchange Online audit retention enabled]($portalLink)."
    } else {
        $testResultMarkdown = "Your tenant does not have [Exchange Online audit retention enabled]($portalLink)."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
