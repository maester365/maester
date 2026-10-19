function Test-MtCisDlpPoliciesCopilot {
    <#
    .SYNOPSIS
        Checks that a data loss prevention policy for Microsoft 365 Copilot is enabled for all users.

    .DESCRIPTION
        Checks that at least one data loss prevention policy for the Copilot experiences location is turned on and applies to all users.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.3, L1)

    .EXAMPLE
        Test-MtCisDlpPoliciesCopilot

        Returns true if an enabled DLP policy applies to Microsoft 365 Copilot.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.3.2.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.2.3',
        Title = 'Ensure DLP policies are published for Copilot users',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'ai',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1213.002', 'T1530'),
        Control = ('cis-m365:3.2.3', 'nist-800-53-r5:AC-4'),
        Service = 'SecurityCompliance',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting data loss prevention policies...'
    $policies = @(Get-MtExo -Request DlpCompliancePolicy)

    $report = foreach ($policy in $policies) {
        $isCopilot = @($policy.EnforcementPlanes) -contains 'CopilotExperiences'
        $allUsers = @($policy.LocationInclusions.ImmutableIdentity) -contains 'All'
        $unitScoped = @($policy.PolicyRBACScopes | Where-Object { $_ }).Count -gt 0
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Copilot = $isCopilot
            AllUsers = $allUsers
            Pass = $isCopilot -and $policy.Mode -eq 'Enable' -and $allUsers -and -not $unitScoped
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -ge 1

    $passText = 'A data loss prevention policy for Microsoft 365 Copilot is enabled for all users.'
    $failText = 'No enabled data loss prevention policy applies to Microsoft 365 Copilot for all users.'

    $resultMd = "| Policy | Mode | Copilot location | All users | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.Mode) | $($row.Copilot) | $($row.AllUsers) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
