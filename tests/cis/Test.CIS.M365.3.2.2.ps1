function Test-MtCisDlpPoliciesTeams {
    <#
    .SYNOPSIS
        Checks that at least one data loss prevention policy that covers Microsoft Teams is enabled.

    .DESCRIPTION
        Checks that at least one data loss prevention policy that is not a Copilot policy includes the Teams workload and is turned on.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.2, L1)

    .EXAMPLE
        Test-MtCisDlpPoliciesTeams

        Returns true if an enabled DLP policy covers Microsoft Teams.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.3.2.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.2.2',
        Title = 'Ensure DLP policies are enabled for Microsoft Teams',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1213', 'T1530', 'T1567'),
        Control = ('cis-m365:3.2.2', 'nist-800-53-r5:AC-4'),
        Service = 'SecurityCompliance',
        License = 'COMMUNICATIONS_DLP',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting data loss prevention policies...'
    $policies = @(Get-MtExo -Request DlpCompliancePolicy | Where-Object { $_.EnforcementPlanes -notcontains 'CopilotExperiences' })

    $report = foreach ($policy in $policies) {
        $coversTeams = "$($policy.Workload)" -match 'Teams'
        # TeamsLocation must include All (all accounts) in an enabled policy
        $coversAll = @($policy.TeamsLocation.ImmutableIdentity) -contains 'All'
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Workload = "$($policy.Workload)"
            AllAccounts = $coversAll
            Pass = $coversTeams -and $policy.Mode -eq 'Enable' -and $coversAll
        }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -ge 1

    $passText = 'At least one data loss prevention policy that covers Microsoft Teams for all accounts is enabled.'
    $failText = if ($policies.Count -eq 0) { 'No data loss prevention policy was found.' } else { 'No enabled data loss prevention policy covers Microsoft Teams for all accounts.' }

    $resultMd = "| Policy | Mode | Workload | All accounts | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $allText = if ($row.AllAccounts) { 'Yes' } else { 'No' }
        $resultMd += "| $($row.Name) | $($row.Mode) | $($row.Workload) | $allText | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
