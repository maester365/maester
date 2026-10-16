function Test-MtCisAppPasswordAdditionBlocked {
    <#
    .SYNOPSIS
        Checks that the default app management policy blocks adding password credentials to apps and service principals.

    .DESCRIPTION
        Checks that the default app management policy is enabled and that its password addition restriction is enabled and already in effect for both applications and service principals, so that client secrets cannot be added and certificates or federated credentials are used instead.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.5.3, L2)

    .EXAMPLE
        Test-MtCisAppPasswordAdditionBlocked

        Returns true if the default app management policy blocks adding password credentials.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.5.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.5.3',
        Title = 'Ensure password addition is blocked for applications',
        Product = 'entra',
        Feature = 'applications',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1098.001', 'T1528'),
        Control = ('cis-m365:5.1.5.3', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the default app management policy...'
    $appPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/defaultAppManagementPolicy' -DisableCache

    $scopes = @(
        [pscustomobject]@{ Name = 'Applications'; Restrictions = @($appPolicy.applicationRestrictions.passwordCredentials) }
        [pscustomobject]@{ Name = 'Service principals'; Restrictions = @($appPolicy.servicePrincipalRestrictions.passwordCredentials) }
    )

    $report = foreach ($scope in $scopes) {
        $restriction = $scope.Restrictions | Where-Object { $_.restrictionType -eq 'passwordAddition' } | Select-Object -First 1
        $startDate = $restriction.restrictForAppsCreatedAfterDateTime
        $appliesNow = $null -eq $startDate -or ([datetime]$startDate).ToUniversalTime() -le [datetime]::UtcNow
        $checks = [ordered]@{
            'Default policy enabled' = $appPolicy.isEnabled -eq $true
            'Restriction enabled' = $restriction.state -eq 'enabled'
            'Applies to existing apps' = [bool]$appliesNow
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{
            Scope = $scope.Name
            State = if ($restriction.state) { $restriction.state } else { 'Not found' }
            Lifetime = ''
            Failed = $failed -join ', '
            Pass = $failed.Count -eq 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Adding password credentials is blocked for applications and service principals.'
    $failText = 'Adding password credentials is not blocked for applications and service principals.'

    $resultMd = "| Scope | Restriction state | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Scope) | $($row.State) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
