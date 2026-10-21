function Test-MtCisAdminSignInFrequency {
    <#
    .SYNOPSIS
        Checks that administrative roles have a short sign-in frequency and non-persistent browser sessions.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy sets a sign-in frequency of no more than the allowed number of hours, or every time, and disables persistent browser sessions for the administrative roles in all cloud apps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.4, L1)

    .EXAMPLE
        Test-MtCisAdminSignInFrequency

        Returns true if an enabled policy limits sign-in frequency and browser persistence for administrators.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.4',
        Title = 'Ensure Sign-in frequency is enabled and browser sessions are not persistent for Administrative users',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1550.004',
        Control = ('cis-m365:5.2.2.4', 'nist-800-53-r5:AC-12'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum sign-in frequency in hours for administrative roles.
        [ValidateRange(1, 720)]
        [int] $MaximumSignInFrequencyHours = 4
    )

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { $_.sessionControls.persistentBrowser.isEnabled })

    $report = foreach ($policy in $candidates) {
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AdministratorRoles)
        $frequency = $policy.sessionControls.signInFrequency
        $frequencyHours = $null
        if ($frequency.frequencyInterval -eq 'timeBased') {
            if ($frequency.type -eq 'hours') {
                $frequencyHours = [int]$frequency.value
            } elseif ($frequency.type -eq 'days') {
                $frequencyHours = [int]$frequency.value * 24
            }
        }
        $frequencyOk = $frequency.frequencyInterval -eq 'everyTime' -or ($null -ne $frequencyHours -and $frequencyHours -le $MaximumSignInFrequencyHours)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Sign-in frequency enabled' = [bool]$frequency.isEnabled
            'Sign-in frequency within limit' = [bool]$frequencyOk
            'Persistent browser disabled' = $policy.sessionControls.persistentBrowser.isEnabled -eq $true -and $policy.sessionControls.persistentBrowser.mode -eq 'never'
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $failedText = $failed -join ', '
        if ($problems.Count -gt 0) { $failedText += " ($($problems -join '; '))" }
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failedText; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy limits the sign-in frequency and disables persistent browser sessions for the administrative roles.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that configures persistent browser sessions was found.' } else { 'No enabled Conditional Access policy limits the sign-in frequency and disables persistent browser sessions for all the administrative roles.' }

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
