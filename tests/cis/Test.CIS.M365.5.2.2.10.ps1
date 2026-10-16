function Test-MtCisManagedDeviceForSecurityInfo {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires a managed device to register security information.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy applies to all users for the register security information user action and requires a compliant device, optionally together with a hybrid joined device, using the OR operator.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.10, L1)

    .EXAMPLE
        Test-MtCisManagedDeviceForSecurityInfo

        Returns true if an enabled policy requires a managed device to register security information.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.10
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.10',
        Title = 'Ensure a managed device is required to register security information',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1098.005'),
        Control = ('cis-m365:5.2.2.10', 'nist-800-53-r5:IA-3'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy

    $candidates = @($policies | Where-Object { @($_.conditions.applications.includeUserActions).Count -gt 0 })

    $report = foreach ($policy in $candidates) {
        $grants = @($policy.grantControls.builtInControls)
        $otherGrants = @($grants | Where-Object { $_ -ne 'compliantDevice' -and $_ -ne 'domainJoinedDevice' })
        $checks = [ordered]@{
            'All users' = @($policy.conditions.users.includeUsers) -contains 'All'
            'Register security information' = @($policy.conditions.applications.includeUserActions) -contains 'urn:user:registersecurityinfo'
            'Compliant device required' = $grants -contains 'compliantDevice' -and $otherGrants.Count -eq 0
            'Operator is OR' = $policy.grantControls.operator -eq 'OR'
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy requires a managed device to register security information.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that targets user actions was found.' } else { 'No enabled Conditional Access policy requires a managed device to register security information.' }

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