function Test-MtCisIntuneEnrollmentSignInFrequency {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires MFA every time for Microsoft Intune enrollment.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy applies to all users and the Microsoft Intune Enrollment application, requires MFA and sets the sign-in frequency to every time.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.11, L1)

    .EXAMPLE
        Test-MtCisIntuneEnrollmentSignInFrequency

        Returns true if an enabled policy requires MFA every time for Intune enrollment.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.11
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.11',
        Title = 'Ensure sign-in frequency for Intune Enrollment is set to ''Every time''',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1098.005',
        Control = ('cis-m365:5.2.2.11', 'nist-800-53-r5:IA-11'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { @($_.conditions.applications.includeApplications) -contains 'd4ebce55-015a-49b5-a083-c84d1797ae8c' })

    $report = foreach ($policy in $candidates) {
        $frequency = $policy.sessionControls.signInFrequency
        $checks = [ordered]@{
            'All users' = @($policy.conditions.users.includeUsers) -contains 'All'
            'Intune Enrollment app' = @($policy.conditions.applications.includeApplications) -contains 'd4ebce55-015a-49b5-a083-c84d1797ae8c'
            'MFA required' = [bool](@($policy.grantControls.builtInControls) -contains 'mfa' -or $policy.grantControls.authenticationStrength.id)
            'Sign-in frequency enabled' = [bool]$frequency.isEnabled
            'Sign-in frequency every time' = $frequency.frequencyInterval -eq 'everyTime'
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy requires MFA every time for Microsoft Intune enrollment.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that targets the Microsoft Intune Enrollment application was found.' } else { 'No enabled Conditional Access policy requires MFA every time for Microsoft Intune enrollment.' }

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
