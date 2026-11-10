function Test-MtCisaAuditLogRetention {
    <#
    .SYNOPSIS
    Checks state of purview

    .DESCRIPTION
    Audit logs SHALL be retained and searchable for a minimum of 3 months and retrievable for a minimum of 12 months.

    .EXAMPLE
    Test-MtCisaAuditLogRetention

    Returns true if audit log retention enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAuditLogRetention
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.5.2',
        Title = 'Audit logs SHALL be retained and searchable for a minimum of 3 months and retrievable for a minimum of 12 months.',
        Product = 'exchange',
        RelatedProduct = 'purview',
        Feature = 'audit-logging',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1070',
        Control = 'cisa-scuba:MS.SECURITYSUITE.5.2',
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
        $testResultMarkdown = "Well done. An enabled [Exchange Online audit retention policy]($portalLink) covers the required Exchange record types for at least 12 months. Confirm 3-month searchability in the Audit portal."
    } else {
        $testResultMarkdown = "Your tenant does not have an enabled [Exchange Online audit retention policy]($portalLink) covering the required Exchange record types for at least 12 months."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
