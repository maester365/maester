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
        Product = 'purview',
        Feature = 'audit',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1685.002',
        Control = ('cis-m365:3.1.1', 'nist-800-53-r5:AU-12'),
        Service = 'ExchangeOnline',
        Author = 'NZLostboy',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Get audit log search status'
    $auditLogSearch = Get-MtExo -Request AdminAuditLogConfig

    $usableConfig = @($auditLogSearch | Where-Object { $null -ne $_ -and $null -ne $_.UnifiedAuditLogIngestionEnabled })
    if ($usableConfig.Count -eq 0) {
        # An empty collection filters to nothing, the if below is false, and its else branch
        # is the pass. Without this guard the check reports audit log search as enabled for a
        # tenant that returned no configuration at all.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    if ($usableConfig | Where-Object { $_.UnifiedAuditLogIngestionEnabled -ne 'True' }) {
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
