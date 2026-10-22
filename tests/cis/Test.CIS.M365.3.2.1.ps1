function Test-MtCisDlpPoliciesEnabled {
    <#
    .SYNOPSIS
        Checks that at least one data loss prevention policy is enabled.

    .DESCRIPTION
        Checks that at least one data loss prevention policy that is not a Copilot policy is enabled.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.1, L1)

    .EXAMPLE
        Test-MtCisDlpPoliciesEnabled

        Returns true if a non-Copilot DLP policy is enabled.

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
    $policies = @(Get-MtExo -Request DlpCompliancePolicy | Where-Object { $_.EnforcementPlanes -notcontains 'CopilotExperiences' })

    $report = foreach ($policy in $policies) {
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Pass = $policy.Mode -eq 'Enable'
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -ge 1

    $passText = 'At least one non-Copilot data loss prevention policy is enabled.'
    $failText = if ($policies.Count -eq 0) { 'No non-Copilot data loss prevention policy was found.' } else { 'No non-Copilot data loss prevention policy is enabled.' }

    $resultMd = "| Policy | Mode | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.Mode) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
