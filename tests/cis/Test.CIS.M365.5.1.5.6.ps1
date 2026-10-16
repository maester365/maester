function Test-MtCisAppCertificateLifetime {
    <#
    .SYNOPSIS
        Checks that the default app management policy limits the lifetime of application certificates.

    .DESCRIPTION
        Checks that the default app management policy is enabled and that its asymmetric key lifetime restriction is enabled, in effect, and limited to the allowed number of days for both applications and service principals.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.5.6, L1)

    .EXAMPLE
        Test-MtCisAppCertificateLifetime

        Returns true if application certificate lifetime is limited to 180 days or less.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.5.6
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.5.6',
        Title = 'Ensure maximum certificate lifetime for applications does not exceed 180 days',
        Product = 'entra',
        Feature = 'applications',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1098.001', 'T1528'),
        Control = ('cis-m365:5.1.5.6', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum lifetime of an application certificate in days.
        [ValidateRange(1, 730)]
        [int] $MaximumLifetimeDays = 180
    )

    Write-Verbose 'Getting the default app management policy...'
    $appPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/defaultAppManagementPolicy' -DisableCache

    $scopes = @(
        [pscustomobject]@{ Name = 'Applications'; Restrictions = @($appPolicy.applicationRestrictions.keyCredentials) }
        [pscustomobject]@{ Name = 'Service principals'; Restrictions = @($appPolicy.servicePrincipalRestrictions.keyCredentials) }
    )

    $report = foreach ($scope in $scopes) {
        $restriction = $scope.Restrictions | Where-Object { $_.restrictionType -eq 'asymmetricKeyLifetime' } | Select-Object -First 1
        $startDate = $restriction.restrictForAppsCreatedAfterDateTime
        $appliesNow = $null -eq $startDate -or ([datetime]$startDate).ToUniversalTime() -le [datetime]::UtcNow
        $maxLifetime = $restriction.maxLifetime
        $lifetimeDays = $null
        if ($maxLifetime) {
            $lifetimeDays = [System.Xml.XmlConvert]::ToTimeSpan($maxLifetime).TotalDays
        }
        $checks = [ordered]@{
            'Default policy enabled' = $appPolicy.isEnabled -eq $true
            'Restriction enabled' = $restriction.state -eq 'enabled'
            'Lifetime within limit' = $null -ne $lifetimeDays -and $lifetimeDays -le $MaximumLifetimeDays
            'Applies to existing apps' = [bool]$appliesNow
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{
            Scope = $scope.Name
            State = if ($restriction.state) { $restriction.state } else { 'Not found' }
            Lifetime = if ($null -ne $lifetimeDays) { "$lifetimeDays days" } else { 'Not set' }
            Failed = $failed -join ', '
            Pass = $failed.Count -eq 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The lifetime of application certificates is limited for applications and service principals.'
    $failText = 'The lifetime of application certificates is not limited as required for applications and service principals.'

    $resultMd = "| Scope | Restriction state | Maximum lifetime | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Scope) | $($row.State) | $($row.Lifetime) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
