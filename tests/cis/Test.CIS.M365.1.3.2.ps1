function Test-MtCisIdleSessionTimeout {
    <#
    .SYNOPSIS
        Checks that idle session timeout is 3 hours or less and that a Conditional Access policy applies it to unmanaged devices.

    .DESCRIPTION
        Checks that an activity-based timeout policy sets the web session idle timeout to no more than the allowed number of hours, and that an enabled Conditional Access policy uses app enforced restrictions for browser sessions of Microsoft 365 apps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.2, L2)

    .EXAMPLE
        Test-MtCisIdleSessionTimeout

        Returns true if the idle session timeout is 3 hours or less and a Conditional Access policy enforces it for browsers.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.1.3.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.2',
        Title = 'Ensure ''Idle session timeout'' is set to ''3 hours (or less)'' for unmanaged devices',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'organization-settings',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1550.004',
        Control = ('cis-m365:1.3.2', 'nist-800-53-r5:AC-12'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum idle session timeout in hours.
        [ValidateRange(1, 24)]
        [int] $MaximumIdleTimeoutHours = 3
    )

    Write-Verbose 'Getting the activity-based timeout policy and Conditional Access policies...'
    $timeoutPolicies = @(Invoke-MtGraphRequest -RelativeUri 'policies/activityBasedTimeoutPolicies' | Where-Object { $_ })
    $policies = Get-MtConditionalAccessPolicy
    $emergency = @(Get-MtEmergencyAccessAccount | ForEach-Object { $_.ObjectId })

    $timeoutSpan = $null
    if ($timeoutPolicies.Count -gt 0) {
        $definition = @($timeoutPolicies[0].definition)[0] | ConvertFrom-Json
        $timeout = $definition.ActivityBasedTimeoutPolicy.ApplicationPolicies[0].WebSessionIdleTimeout
        if ($timeout) {
            $timeoutSpan = [timespan]::Parse($timeout)
        }
    }
    $timeoutOk = $null -ne $timeoutSpan -and $timeoutSpan -le [timespan]::FromHours($MaximumIdleTimeoutHours)

    $candidates = @($policies | Where-Object { $_.sessionControls.applicationEnforcedRestrictions.isEnabled })
    $report = foreach ($policy in $candidates) {
        $apps = @($policy.conditions.applications.includeApplications)
        $clients = @($policy.conditions.clientAppTypes)
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -EmergencyAccessId $emergency -Users AllUsers -Applications 'Office365' -TargetedCondition ClientAppTypes)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Office 365 apps only' = $apps.Count -eq 1 -and $apps -contains 'Office365'
            'Browser clients only' = $clients.Count -eq 1 -and $clients -contains 'browser'
            'App enforced restrictions' = $policy.sessionControls.applicationEnforcedRestrictions.isEnabled -eq $true
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $failedText = $failedChecks -join ', '
        if ($problems.Count -gt 0) { $failedText += " ($($problems -join '; '))" }
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failedText; Pass = $failedChecks.Count -eq 0 }
    }
    $policyOk = @($report | Where-Object { $_.Pass }).Count -ge 1
    $testResult = $timeoutOk -and $policyOk

    $passText = 'The idle session timeout is limited and a Conditional Access policy enforces it for browser sessions.'
    $failText = if (-not $timeoutOk -and -not $policyOk) { 'There is no idle session timeout of 3 hours or less, and no Conditional Access policy that enforces app restrictions for browsers.' } elseif (-not $timeoutOk) { 'There is no idle session timeout of 3 hours or less.' } else { 'No Conditional Access policy enforces app restrictions for browser sessions of Microsoft 365 apps.' }

    $timeoutText = if ($timeoutSpan) { "$($timeoutSpan.TotalHours) hours" } else { 'Not configured' }
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| Web session idle timeout | $timeoutText | $(if ($timeoutOk) { '✅ Pass' } else { '❌ Fail' }) |`n"
    $resultMd += "| Conditional Access policy with app enforced restrictions | $(if ($policyOk) { 'Found' } else { 'Not found' }) | $(if ($policyOk) { '✅ Pass' } else { '❌ Fail' }) |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) ($($row.State)) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
