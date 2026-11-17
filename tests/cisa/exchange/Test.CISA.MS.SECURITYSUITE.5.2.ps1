function Test-MtCisaAuditLogRetention {
    <#
    .SYNOPSIS
    Checks Exchange audit-retention evidence and requests manual verification.

    .DESCRIPTION
    Audit logs SHALL be retained and searchable for a minimum of 3 months and retrievable for a minimum of 12 months.

    .EXAMPLE
    Test-MtCisaAuditLogRetention

    Returns $null with an Investigate result for this manual benchmark requirement so CI exports do not report it as passed.

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
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policyLookupFailed = $false
    try {
        $policies = @(Get-MtExo -Request UnifiedAuditLogRetentionPolicy)
    }
    catch {
        $policyLookupFailed = $true
        $policyLookupError = $_.Exception.Message
        $policies = @()
    }

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

    $portalLink = 'https://purview.microsoft.com/audit/auditpolicies'
    if ($policyLookupFailed) {
        $policySummary = 'Exchange audit-retention policy evidence could not be retrieved.'
        if ($policyLookupError) {
            $policySummary += " $policyLookupError"
        }
    }
    elseif ($resultPolicies.Count -gt 0) {
        $policyNames = @($resultPolicies | ForEach-Object { $_.Name ?? $_.Identity } | Where-Object { $_ })
        $policySummary = "Found enabled Exchange audit retention policy(ies) covering the checked Exchange record types for at least 12 months: $($policyNames -join ', ')."
    } else {
        $policySummary = 'No enabled Exchange audit retention policy was found that covers the checked Exchange record types for at least 12 months. Other approved retention or log-export solutions may still satisfy the requirement.'
    }

    $testResultMarkdown = "Manual verification required. $policySummary This check does not assess the user scope of these policies. CISA also requires audit logs to be searchable for at least three months and retrievable for at least 12 months across the applicable workloads. This check cannot verify the full requirement. Confirm the policy scope, search and retention coverage in the [Audit portal]($portalLink) or the approved alternative log-archive solution."

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $null
}
