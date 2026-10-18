function Test-MtCisGuestAccessReviews {
    <#
    .SYNOPSIS
        Checks that a recurring access review of guest users exists with the required settings.

    .DESCRIPTION
        Checks that at least one access review that targets guest users repeats weekly or monthly, runs for no more than 14 days, sends notifications and reminders, requires a justification, applies decisions automatically with a default decision of deny, and never ends.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.3.2, L1)

    .EXAMPLE
        Test-MtCisGuestAccessReviews

        Returns true if a compliant access review for guests exists.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.3.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.3.2',
        Title = 'Ensure ''Access reviews'' for guest users are configured',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.3.2', 'nist-800-53-r5:AC-2'),
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum number of days that each review instance stays open.
        [ValidateRange(1, 180)]
        [int] $MaximumInstanceDurationInDays = 14
    )

    Write-Verbose 'Getting access review definitions...'
    $reviews = Invoke-MtGraphRequest -RelativeUri 'identityGovernance/accessReviews/definitions'
    $guestReviews = @($reviews | Where-Object { $_.scope.query -match "userType eq 'Guest'" -or (@($_.scope.principalScopes.query) -join ' ') -match "userType eq 'Guest'" })

    $report = foreach ($review in $guestReviews) {
        $settings = $review.settings
        $patternType = $settings.recurrence.pattern.type
        $interval = $settings.recurrence.pattern.interval
        # Multi-stage reviews take their reviewers and duration from the stages.
        $stages = @($review.stageSettings | Where-Object { $_ })
        $reviewers = @($review.reviewers | Where-Object { $_ })
        $durationInDays = $settings.instanceDurationInDays
        if ($stages.Count -gt 0) {
            $reviewers = @($stages | ForEach-Object { $_.reviewers } | Where-Object { $_ })
            $durationInDays = ($stages | Measure-Object -Property durationInDays -Sum).Sum
        }
        $checks = [ordered]@{
            'Weekly or monthly' = ($patternType -eq 'absoluteMonthly' -and $interval -eq 1) -or $patternType -eq 'weekly'
            'Reviewers' = $reviewers.Count -ge 1
            'Notifications' = [bool]$settings.mailNotificationsEnabled
            'Reminders' = [bool]$settings.reminderNotificationsEnabled
            'Duration' = $null -ne $durationInDays -and $durationInDays -le $MaximumInstanceDurationInDays
            'Justification' = [bool]$settings.justificationRequiredOnApproval
            'Auto apply' = [bool]$settings.autoApplyDecisionsEnabled
            'Default decision deny' = $settings.defaultDecisionEnabled -eq $true -and $settings.defaultDecision -eq 'Deny'
            'No end date' = $settings.recurrence.range.type -eq 'noEnd'
        }
        $failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $review.displayName; Status = $review.status; Failed = $failedChecks -join ', '; Pass = $failedChecks.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0

    $passText = 'An access review for guest users is configured as required.'
    $failText = if ($guestReviews.Count -eq 0) { 'No access review that targets guest users was found.' } else { 'No access review for guest users meets all the required settings.' }

    $resultMd = "| Access review | Status | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.Status) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
