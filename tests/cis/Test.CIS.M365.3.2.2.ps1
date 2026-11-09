function Test-MtCisTeamsDlpPolicy {
    <#
    .SYNOPSIS
        Checks that at least one data loss prevention policy that covers Microsoft Teams is enabled.

    .DESCRIPTION
        Checks that at least one enabled data loss prevention policy includes the Teams workload for all accounts.
        Policies with Teams location exceptions require manual review of the permitted exceptions.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.2, L1)

    .EXAMPLE
        Test-MtCisTeamsDlpPolicy

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
    $policies = @(Get-MtExo -Request DlpCompliancePolicy)

    $report = foreach ($policy in $policies) {
        $coversTeams = "$($policy.Workload)" -match 'Teams'
        $teamsLocations = @($policy.TeamsLocation | ForEach-Object {
                if ($_ -is [string]) { $_ }
                else { $_.ImmutableIdentity ?? $_.Identity ?? $_.Name ?? $_.DisplayName }
            })
        $coversAll = $teamsLocations -contains 'All'
        $exceptions = @($policy.TeamsLocationException | Where-Object { $_ })
        $unitScoped = @($policy.PolicyRBACScopes | Where-Object { $_ }).Count -gt 0
        $qualifies = $coversTeams -and $policy.Mode -eq 'Enable' -and $coversAll -and -not $unitScoped
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Workload = "$($policy.Workload)"
            AllAccounts = $coversAll -and -not $unitScoped
            Exceptions = (@($exceptions | ForEach-Object {
                        if ($_ -is [string]) { $_ }
                        else { ConvertTo-Json -InputObject $_ -Depth 20 -Compress }
                    }) -join '; ')
            Pass = $qualifies -and $exceptions.Count -eq 0
            ReviewRequired = $qualifies -and $exceptions.Count -gt 0
        }
    }
    $passingPolicy = @($report | Where-Object { $_.Pass }).Count -ge 1
    $reviewRequired = -not $passingPolicy -and @($report | Where-Object { $_.ReviewRequired }).Count -gt 0
    $testResult = $passingPolicy -or $reviewRequired

    $passText = 'At least one data loss prevention policy that covers Microsoft Teams for all accounts is enabled.'
    $reviewText = 'An enabled data loss prevention policy covers Microsoft Teams for all accounts, but its Teams location exceptions need manual review. Confirm that each listed exception is permitted by the organization.'
    $failText = if ($policies.Count -eq 0) { 'No data loss prevention policy was found.' } else { 'No enabled data loss prevention policy covers Microsoft Teams for all accounts.' }

    $resultMd = "| Policy | Mode | Workload | All accounts | Teams location exceptions | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $allText = if ($row.AllAccounts) { 'Yes' } else { 'No' }
        $result = if ($row.Pass) { '✅ Pass' } elseif ($row.ReviewRequired) { 'Review' } else { '❌ Fail' }
        $resultMd += "| $(Get-MtSafeMarkdown $row.Name) | $(Get-MtSafeMarkdown $row.Mode) | $(Get-MtSafeMarkdown $row.Workload) | $allText | $(Get-MtSafeMarkdown $row.Exceptions) | $result |`n"
    }

    if ($passingPolicy) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    }
    elseif ($reviewRequired) {
        $testResultMarkdown = "$reviewText`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown.Replace('%TestResult%', $resultMd)

    if ($reviewRequired) {
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    }
    else {
        Add-MtTestResultDetail -Result $testResultMarkdown
    }
    return $testResult
}
