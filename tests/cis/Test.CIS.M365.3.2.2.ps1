function Test-MtCisTeamsDlpPolicy {
    <#
    .SYNOPSIS
        Checks that an enabled Teams data loss prevention policy covers all accounts and has an enabled rule.

    .DESCRIPTION
        Checks that at least one enabled data loss prevention policy includes the Teams workload for all accounts and has an enabled rule.
        Policies with Teams location exceptions require manual review of the permitted exceptions.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.2, L1)

    .EXAMPLE
        Test-MtCisTeamsDlpPolicy

        Returns true if an enabled DLP policy covers Microsoft Teams and has an enabled rule.

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
    $rules = @(Get-MtExo -Request DlpComplianceRule)

    $report = foreach ($policy in $policies) {
        $coversTeams = "$($policy.Workload)" -match 'Teams'
        $teamsLocations = @($policy.TeamsLocation | ForEach-Object {
                if ($_ -is [string]) { $_ }
                else { $_.ImmutableIdentity ?? $_.Identity ?? $_.Name ?? $_.DisplayName }
            })
        $coversAll = $teamsLocations -contains 'All'
        $exceptions = @($policy.TeamsLocationException | Where-Object { $_ })
        $unitScoped = @($policy.PolicyRBACScopes | Where-Object { $_ }).Count -gt 0
        $enabledRules = @($rules | Where-Object {
                $_.ParentPolicyName -eq $policy.Name -and
                $_.PSObject.Properties['Disabled'] -and
                $_.Disabled -is [bool] -and
                -not $_.Disabled
            })
        $qualifies = (
            $coversTeams -and
            $policy.Mode -eq 'Enable' -and
            $coversAll -and
            -not $unitScoped -and
            $enabledRules.Count -gt 0
        )
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Workload = "$($policy.Workload)"
            AllAccounts = $coversAll -and -not $unitScoped
            EnabledRules = $enabledRules.Count
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

    $passText = 'At least one enabled data loss prevention policy covers Microsoft Teams for all accounts and has an enabled rule.'
    $reviewText = 'An enabled data loss prevention policy with an enabled rule covers Microsoft Teams for all accounts, but its Teams location exceptions need manual review. Confirm that each listed exception is permitted by the organization.'
    $failText = if ($policies.Count -eq 0) { 'No data loss prevention policy was found.' } else { 'No enabled data loss prevention policy covers Microsoft Teams for all accounts with an enabled rule.' }

    $resultMd = "| Policy | Mode | Workload | All accounts | Enabled rules | Teams location exceptions | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $allText = if ($row.AllAccounts) { 'Yes' } else { 'No' }
        $result = if ($row.Pass) { '✅ Pass' } elseif ($row.ReviewRequired) { 'Review' } else { '❌ Fail' }
        $resultMd += "| $(Get-MtSafeMarkdown $row.Name) | $(Get-MtSafeMarkdown $row.Mode) | $(Get-MtSafeMarkdown $row.Workload) | $allText | $($row.EnabledRules) | $(Get-MtSafeMarkdown $row.Exceptions) | $result |`n"
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
