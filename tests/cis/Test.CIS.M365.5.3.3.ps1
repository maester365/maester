function Test-MtCisPrivilegedRoleAccessReviews {
    <#
    .SYNOPSIS
        Checks that recurring access reviews exist for the Global, Exchange, SharePoint, Teams, Security and Privileged Role Administrator roles.

    .DESCRIPTION
        Checks that each of the Global Administrator, Exchange Administrator, SharePoint Administrator, Teams Administrator, Security Administrator and Privileged Role Administrator roles has an active access review of users and groups that repeats weekly or monthly, runs for no more than 14 days, sends notifications and reminders, requires a justification, applies decisions automatically and never ends.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.3.3, L1)

    .EXAMPLE
        Test-MtCisPrivilegedRoleAccessReviews

        Returns true if each of the five privileged roles has a compliant access review.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.3.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.3.3',
        Title = 'Ensure ''Access reviews'' for privileged roles are configured',
        Product = 'entra',
        Feature = 'identity-governance',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.3.3', 'nist-800-53-r5:AC-6(7)'),
        Service = 'Graph',
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
    $roleList = @{
        '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
        '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c' = 'SharePoint Administrator'
        '69091246-20e8-4a56-aa4d-066075b2a7a8' = 'Teams Administrator'
        '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
        'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
    }
    $reviews = Invoke-MtGraphRequest -RelativeUri 'identityGovernance/accessReviews/definitions' -DisableCache
    $roleReviews = @($reviews | Where-Object { (@($_.scope.resourceScopes.query) -join ' ') -match 'roleDefinitions' })

    $report = foreach ($review in $roleReviews) {
        $resourceQuery = @($review.scope.resourceScopes.query) -join ' '
        $matchedRoleId = @($roleList.Keys | Where-Object { $resourceQuery -match $_ }) | Select-Object -First 1
        $startDate = $review.settings.recurrence.range.startDate
        if (-not $matchedRoleId -or [string]::IsNullOrWhiteSpace($startDate)) {
            continue
        }
        $settings = $review.settings
        $patternType = $settings.recurrence.pattern.type
        $interval = $settings.recurrence.pattern.interval
        $principalQuery = @($review.scope.principalScopes.query) -join ' '
        $checks = [ordered]@{
            'Users and groups in scope' = $principalQuery -match 'users' -and $principalQuery -match 'groups'
            'Weekly or monthly' = ($patternType -eq 'absoluteMonthly' -and $interval -eq 1) -or $patternType -eq 'weekly'
            'Started' = ([datetime]$startDate).ToUniversalTime() -le [datetime]::UtcNow
            'Reviewers' = @($review.reviewers).Count -ge 1
            'In progress' = $review.status -eq 'InProgress'
            'Notifications' = [bool]$settings.mailNotificationsEnabled
            'Reminders' = [bool]$settings.reminderNotificationsEnabled
            'Justification' = [bool]$settings.justificationRequiredOnApproval
            'Duration' = $null -ne $settings.instanceDurationInDays -and $settings.instanceDurationInDays -le $MaximumInstanceDurationInDays
            'Auto apply' = [bool]$settings.autoApplyDecisionsEnabled
            'Default decision none' = $settings.defaultDecision -eq 'None'
            'No end date' = $settings.recurrence.range.type -eq 'noEnd'
        }
        $failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $review.displayName; Role = $roleList[$matchedRoleId]; Failed = $failedChecks -join ', '; Pass = $failedChecks.Count -eq 0 }
    }
    $rolesWithReview = @($report | Where-Object { $_.Pass } | ForEach-Object { $_.Role })
    $missingRoles = @($roleList.Values | Where-Object { $rolesWithReview -notcontains $_ } | Sort-Object)
    $testResult = $missingRoles.Count -eq 0

    $passText = 'Each of the privileged roles has a compliant access review.'
    $failText = "No compliant access review exists for: $($missingRoles -join ', ')."

    $resultMd = "| Role | Access review | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Role) | $($row.Name) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }
    foreach ($roleName in $missingRoles) {
        if (@($report | Where-Object { $_.Role -eq $roleName }).Count -eq 0) {
            $resultMd += "| $roleName | Not found | No access review | ❌ Fail |`n"
        }
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
