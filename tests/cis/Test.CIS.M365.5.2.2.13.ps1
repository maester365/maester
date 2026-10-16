function Test-MtCisPeriodicReauthentication {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy limits the sign-in frequency for all users.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy sets a sign-in frequency of no more than the allowed number of days, or every time, for all users in all cloud apps. Policies that apply only to risky sign-ins are not counted.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.13, L1)

    .EXAMPLE
        Test-MtCisPeriodicReauthentication

        Returns true if an enabled policy requires periodic reauthentication for all users.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.13
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.13',
        Title = 'Ensure that periodic reauthentication is required for all users',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1539', 'T1550.004'),
        Control = ('cis-m365:5.2.2.13', 'nist-800-53-r5:AC-12'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum sign-in frequency in days for all users.
        [ValidateRange(1, 90)]
        [int] $MaximumSignInFrequencyDays = 7
    )

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { $_.sessionControls.signInFrequency.isEnabled -eq $true -and (@($_.conditions.signInRiskLevels).Count -eq 0 -and @($_.conditions.userRiskLevels).Count -eq 0) })

    $report = foreach ($policy in $candidates) {
        $frequency = $policy.sessionControls.signInFrequency
        $frequencyHours = $null
        if ($frequency.frequencyInterval -eq 'timeBased') {
            if ($frequency.type -eq 'hours') {
                $frequencyHours = [int]$frequency.value
            } elseif ($frequency.type -eq 'days') {
                $frequencyHours = [int]$frequency.value * 24
            }
        }
        $frequencyOk = $frequency.frequencyInterval -eq 'everyTime' -or ($null -ne $frequencyHours -and $frequencyHours -le ($MaximumSignInFrequencyDays * 24))
        $checks = [ordered]@{
            'All users' = @($policy.conditions.users.includeUsers) -contains 'All'
            'All applications' = @($policy.conditions.applications.includeApplications) -contains 'All'
            'Sign-in frequency enabled' = [bool]$frequency.isEnabled
            'Sign-in frequency within limit' = [bool]$frequencyOk
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy requires periodic reauthentication for all users.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that configures sign-in frequency was found.' } else { 'No enabled Conditional Access policy requires periodic reauthentication within the allowed limit for all users.' }

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
