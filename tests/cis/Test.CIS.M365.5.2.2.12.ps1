function Test-MtCisBlockDeviceCodeFlow {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy blocks the device code authentication flow for all users.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy blocks the device code flow for all users and all cloud apps. Attackers use device code phishing to obtain tokens without ever seeing the password or the MFA prompt.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.12, L1)

    .EXAMPLE
        Test-MtCisBlockDeviceCodeFlow

        Returns true if an enabled policy blocks the device code flow.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.12
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.12',
        Title = 'Ensure the device code sign-in flow is blocked',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1528', 'T1566'),
        Control = ('cis-m365:5.2.2.12', 'nist-800-53-r5:CM-7'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    # Graph returns transferMethods as one comma-separated string or as an array.
    $candidates = @($policies | Where-Object { @((@($_.conditions.authenticationFlows.transferMethods) -join ',') -split ',' | ForEach-Object { $_.Trim() }) -contains 'deviceCodeFlow' })

    $report = foreach ($policy in $candidates) {
        $methods = @((@($policy.conditions.authenticationFlows.transferMethods) -join ',') -split ',' | ForEach-Object { $_.Trim() })
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AllUsers -TargetedCondition AuthenticationFlows)
        $grantProblems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Device code flow' = $methods -contains 'deviceCodeFlow'
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
    $passText = 'An enabled Conditional Access policy blocks the device code flow for all users.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that targets the device code flow was found.' } else { 'No enabled Conditional Access policy blocks the device code flow for all users.' }

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
