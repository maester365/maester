function Test-MtCisMfaForAllUsers {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires MFA for all users in all cloud apps.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy requires multifactor authentication or an authentication strength for all users in all cloud apps. Policies that apply only to risky sign-ins are not counted because they leave gaps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.2, L1)

    .EXAMPLE
        Test-MtCisMfaForAllUsers

        Returns true if an enabled policy requires MFA for all users and all cloud apps.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.2',
        Title = 'Ensure multifactor authentication is enabled for all users',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110.003'),
        Control = ('cis-m365:5.2.2.2', 'nist-800-53-r5:IA-2(2)'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { (@($_.grantControls.builtInControls) -contains 'mfa' -or $_.grantControls.authenticationStrength.id) -and (@($_.conditions.signInRiskLevels).Count -eq 0 -and @($_.conditions.userRiskLevels).Count -eq 0) })

    $report = foreach ($policy in $candidates) {
        $checks = [ordered]@{
            'All users' = @($policy.conditions.users.includeUsers) -contains 'All'
            'All applications' = @($policy.conditions.applications.includeApplications) -contains 'All'
            'MFA required' = [bool](@($policy.grantControls.builtInControls) -contains 'mfa' -or $policy.grantControls.authenticationStrength.id)
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy requires multifactor authentication for all users and all cloud apps.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that requires multifactor authentication was found.' } else { 'No enabled Conditional Access policy requires multifactor authentication for all users and all cloud apps.' }

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
