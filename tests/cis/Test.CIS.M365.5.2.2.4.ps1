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
        ImplementationCost = 'Low',
        Mitre = ('T1539', 'T1550.004'),
        Control = ('cis-m365:5.2.2.4', 'nist-800-53-r5:AC-12'),
        Service = 'Graph',
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
    $requiredRoles = @{
        '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' = 'Application Administrator'
        'c4e39bd9-1100-46d3-8c65-fb160da0071f' = 'Authentication Administrator'
        'b0f54661-2d74-4c50-afa3-1ec803f12efe' = 'Billing Administrator'
        '158c047a-c907-4556-b7ef-446551a6b5f7' = 'Cloud Application Administrator'
        'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' = 'Conditional Access Administrator'
        '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
        '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
        'f2ef992c-3afb-46b9-b7cf-a126ee74c451' = 'Global Reader'
        '729827e3-9c14-49f7-bb1b-9608f156bbb8' = 'Helpdesk Administrator'
        '966707d0-3269-4727-9be2-8c3a10f19b9d' = 'Password Administrator'
        '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' = 'Privileged Authentication Administrator'
        'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
        '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c' = 'SharePoint Administrator'
        'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
    }

    $candidates = @($policies | Where-Object { $_.sessionControls.persistentBrowser.isEnabled })

    $report = foreach ($policy in $candidates) {
        $includedRoles = @($policy.conditions.users.includeRoles)
        $missingRoles = @($requiredRoles.Keys | Where-Object { $includedRoles -notcontains $_ })
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
            'All administrative roles' = $missingRoles.Count -eq 0
            'All applications' = @($policy.conditions.applications.includeApplications) -contains 'All'
            'Sign-in frequency enabled' = [bool]$frequency.isEnabled
            'Sign-in frequency within limit' = [bool]$frequencyOk
            'Persistent browser disabled' = $policy.sessionControls.persistentBrowser.isEnabled -eq $true -and $policy.sessionControls.persistentBrowser.mode -eq 'never'
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
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