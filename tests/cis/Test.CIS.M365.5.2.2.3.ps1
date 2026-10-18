function Test-MtCisBlockLegacyAuthentication {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy blocks legacy authentication clients for all users.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy blocks access for all users and all cloud apps when the client is Exchange ActiveSync or another legacy client. Legacy protocols cannot do MFA, so attackers use them to bypass it.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.3, L1)

    .EXAMPLE
        Test-MtCisBlockLegacyAuthentication

        Returns true if an enabled policy blocks legacy authentication for all users.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.3',
        Title = 'Enable Conditional Access policies to block legacy authentication',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110.003'),
        Control = ('cis-m365:5.2.2.3', 'nist-800-53-r5:CM-7'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    $emergency = @(Get-MtEmergencyAccessAccount | ForEach-Object { $_.ObjectId })

    $candidates = @($policies | Where-Object { @($_.conditions.clientAppTypes) -contains 'exchangeActiveSync' -or @($_.conditions.clientAppTypes) -contains 'other' })

    $report = foreach ($policy in $candidates) {
        $clientAppTypes = @($policy.conditions.clientAppTypes)
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -EmergencyAccessId $emergency -Users AllUsers -TargetedCondition ClientAppTypes)
        $grantProblems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Legacy client types' = $clientAppTypes -contains 'exchangeActiveSync' -and $clientAppTypes -contains 'other'
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
    $passText = 'An enabled Conditional Access policy blocks legacy authentication for all users.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that targets legacy authentication clients was found.' } else { 'No enabled Conditional Access policy blocks legacy authentication for all users.' }

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
