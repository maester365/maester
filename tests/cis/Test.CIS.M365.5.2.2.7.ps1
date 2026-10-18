function Test-MtCisSignInRiskPolicy {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires MFA for sign-ins with medium or high risk.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy applies to all users and all cloud apps at the medium and high sign-in risk levels and either blocks access, or requires MFA with a sign-in frequency of every time.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.7, L1)

    .EXAMPLE
        Test-MtCisSignInRiskPolicy

        Returns true if an enabled sign-in risk policy covers medium and high risk.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.7
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.7',
        Title = 'Enable Identity Protection sign-in risk policies',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.2.2.7', 'nist-800-53-r5:AC-2(12)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    $emergency = @(Get-MtEmergencyAccessAccount | ForEach-Object { $_.ObjectId })

    $candidates = @($policies | Where-Object { @($_.conditions.signInRiskLevels).Count -gt 0 })

    $report = foreach ($policy in $candidates) {
        $frequency = $policy.sessionControls.signInFrequency
        $blocks = @($policy.grantControls.builtInControls) -contains 'block'
        $riskLevels = @($policy.conditions.signInRiskLevels)
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -EmergencyAccessId $emergency -Users AllUsers -TargetedCondition SignInRiskLevels)
        $grantProblems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Medium and high sign-in risk' = $riskLevels -contains 'high' -and $riskLevels -contains 'medium'
            'MFA required or access blocked' = [bool]($blocks -or @($policy.grantControls.builtInControls) -contains 'mfa' -or $policy.grantControls.authenticationStrength.id)
            'Sign-in frequency every time' = [bool]($blocks -or ($frequency.isEnabled -and $frequency.frequencyInterval -eq 'everyTime'))
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
    $passText = 'An enabled Conditional Access policy responds to medium and high sign-in risk.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that uses the sign-in risk condition was found.' } else { 'No enabled Conditional Access policy responds to medium and high sign-in risk as required.' }

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
