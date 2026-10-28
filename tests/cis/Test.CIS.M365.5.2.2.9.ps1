function Test-MtCisManagedDeviceForAuthentication {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires a compliant device for all users and apps.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy requires a compliant device for all users in all cloud apps. A hybrid joined device may optionally be allowed as an alternative with the OR operator.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.9, L1)

    .EXAMPLE
        Test-MtCisManagedDeviceForAuthentication

        Returns true if an enabled policy requires a compliant device for all users and all cloud apps, optionally allowing a hybrid joined device.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.9
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.9',
        Title = 'Ensure a managed device is required for authentication',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'High',
        ImplementationCost = 'High',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.2.2.9', 'nist-800-53-r5:IA-3'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { @($_.grantControls.builtInControls) -contains 'compliantDevice' -or @($_.grantControls.builtInControls) -contains 'domainJoinedDevice' })

    $report = foreach ($policy in $candidates) {
        $grants = @($policy.grantControls.builtInControls)
        $otherGrants = @($grants | Where-Object { $_ -ne 'compliantDevice' -and $_ -ne 'domainJoinedDevice' })
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AllUsers)
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Compliant device required' = $grants -contains 'compliantDevice' -and $otherGrants.Count -eq 0
            'Operator is OR' = $policy.grantControls.operator -eq 'OR'
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $failedText = $failed -join ', '
        if ($problems.Count -gt 0) { $failedText += " ($($problems -join '; '))" }
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failedText; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy requires a compliant device for all users and all cloud apps, optionally allowing a hybrid joined device.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that requires a compliant or hybrid joined device was found.' } else { 'No enabled Conditional Access policy requires a compliant device for all users and all cloud apps.' }

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
