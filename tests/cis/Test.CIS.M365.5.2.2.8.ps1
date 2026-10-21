function Test-MtCisBlockMediumHighSignInRisk {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy blocks access for medium and high sign-in risk.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy blocks access for all users and all cloud apps at the medium and high sign-in risk levels, without excluded applications.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.8, L2)

    .EXAMPLE
        Test-MtCisBlockMediumHighSignInRisk

        Returns true if an enabled policy blocks medium and high sign-in risk.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.8
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.8',
        Title = 'Ensure ''sign-in risk'' is blocked for medium and high risk',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.2.2.8', 'nist-800-53-r5:AC-2(12)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { @($_.conditions.signInRiskLevels).Count -gt 0 })

    $report = foreach ($policy in $candidates) {
        $riskLevels = @($policy.conditions.signInRiskLevels)
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AllUsers -TargetedCondition SignInRiskLevels)
        $grantProblems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'No excluded applications' = @($policy.conditions.applications.excludeApplications).Count -eq 0
            'Medium and high sign-in risk' = $riskLevels -contains 'high' -and $riskLevels -contains 'medium'
            'Block access' = @($policy.grantControls.builtInControls) -contains 'block'
            'Grant controls combine as required' = $grantProblems.Count -eq 0
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $details = @($problems) + @($grantProblems)
        $failedText = $failed -join ', '
        if ($details.Count -gt 0) { $failedText += " ($($details -join '; '))" }
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failedText; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy blocks access for medium and high sign-in risk.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that uses the sign-in risk condition was found.' } else { 'No enabled Conditional Access policy blocks access for medium and high sign-in risk.' }

    $resultMd = "| Policy | State | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.State) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
