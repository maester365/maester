function Get-MtMarkdownSummaryReport {
    <#
    .Synopsis
    Generates a compact markdown summary report with only result counters.

    .Description
    This markdown report is intended for quick sharing in pull requests, tickets,
    and workflow summaries where only the top-level result counts are needed.
    #>
    [CmdletBinding()]
    param(
        # The Maester test results returned from Invoke-Maester -PassThru
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject] $MaesterResults
    )

    $tenantDisplay = if (![string]::IsNullOrEmpty($MaesterResults.TenantName)) {
        "$($MaesterResults.TenantName) ($($MaesterResults.TenantId))"
    } else {
        "Tenant ID: $($MaesterResults.TenantId)"
    }

    $executedAt = $MaesterResults.ExecutedAt

    $lines = @(
        '# Maester Test Results Summary'
        ''
        "**Tenant:** $tenantDisplay"
        "**Date:** $executedAt"
        ''
        '| Metric | Count |'
        '| - | -: |'
        "| Passed ✅ | $($MaesterResults.PassedCount) |"
        "| Failed ❌ | $($MaesterResults.FailedCount) |"
        "| Investigate 🕵️ | $($MaesterResults.InvestigateCount) |"
        "| Skipped ⏭️ | $($MaesterResults.SkippedCount) |"
        "| Error ⚠️ | $($MaesterResults.ErrorCount) |"
        "| Not Run 🛑 | $($MaesterResults.NotRunCount) |"
        "| Total 📊 | $($MaesterResults.TotalCount) |"
    )

    return ($lines -join "`n")
}
