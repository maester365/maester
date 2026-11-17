function Test-MtCisDlpPoliciesEnabled {
    <#
    .SYNOPSIS
        Checks that at least one data loss prevention policy is enabled.

    .DESCRIPTION
        Checks that at least one enabled data loss prevention policy defines an Exchange, SharePoint, OneDrive or Teams location.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.1, L1)

    .EXAMPLE
        Test-MtCisDlpPoliciesEnabled

        Returns true if an enabled DLP policy defines at least one required workload location.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.3.2.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.2.1',
        Title = 'Ensure DLP policies are enabled',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1213', 'T1530', 'T1567'),
        Control = ('cis-m365:3.2.1', 'nist-800-53-r5:AC-4'),
        Service = 'SecurityCompliance',
        License = 'EXCHANGE_DLP',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting data loss prevention policies...'
    $policies = @(Get-MtExo -Request DlpCompliancePolicy)

    $report = foreach ($policy in $policies) {
        $locations = @('ExchangeLocation', 'SharePointLocation', 'OneDriveLocation', 'TeamsLocation' | Where-Object {
                @($policy.$_ | Where-Object { $_ }).Count -gt 0
            })
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Locations = $locations -join ', '
            Pass = $policy.Mode -eq 'Enable' -and $locations.Count -gt 0
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -ge 1

    $passText = 'At least one enabled data loss prevention policy defines an Exchange, SharePoint, OneDrive or Teams location.'
    $failText = 'No enabled data loss prevention policy defines an Exchange, SharePoint, OneDrive or Teams location.'

    $resultMd = "| Policy | Mode | Required workload locations | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $(Get-MtSafeMarkdown $row.Name) | $(Get-MtSafeMarkdown $row.Mode) | $($row.Locations) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown.Replace('%TestResult%', $resultMd)

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
