function Test-MtCisAppPasswordLifetime {
    <#
    .SYNOPSIS
        Checks that the default app management policy limits the lifetime of application passwords.

    .DESCRIPTION
        Checks that the default app management policy is enabled and that its password lifetime restriction is enabled, its restriction date is reached, no application or service principal was created before that date, and it is limited to the allowed number of days for both applications and service principals.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.1.5.4, L1)

    .EXAMPLE
        Test-MtCisAppPasswordLifetime

        Returns true if application password lifetime is limited to 180 days or less.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.1.5.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.1.5.4',
        Title = 'Ensure password lifetime for applications does not exceed 180 days',
        Product = 'entra',
        Feature = 'applications',
        Area = 'applications',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1098.001',
        Control = ('cis-m365:5.1.5.4', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum lifetime of an application password in days.
        [ValidateRange(1, 730)]
        [int] $MaximumLifetimeDays = 180
    )

    Write-Verbose 'Getting the default app management policy...'
    $appPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/defaultAppManagementPolicy'

    Write-Verbose 'Getting the applications and service principals...'
    $microsoftTenantIds = @('72f988bf-86f1-41af-91ab-2d7cd011db47', 'f8cdef31-a31e-4b4a-93e4-5f571e91255a')
    $applications = @(Invoke-MtGraphRequest -RelativeUri 'applications?$select=createdDateTime')
    # Managed identities take no passwords, and first-party service principals belong to Microsoft.
    $servicePrincipals = @(Invoke-MtGraphRequest -RelativeUri 'servicePrincipals?$select=createdDateTime,appOwnerOrganizationId,servicePrincipalType' | Where-Object { $_.appOwnerOrganizationId -notin $microsoftTenantIds -and $_.servicePrincipalType -ne 'ManagedIdentity' })

    $scopes = @(
        [pscustomobject]@{ Name = 'Applications'; Restrictions = @($appPolicy.applicationRestrictions.passwordCredentials); Objects = $applications; MissingCreatedDate = $null }
        [pscustomobject]@{ Name = 'Service principals'; Restrictions = @($appPolicy.servicePrincipalRestrictions.passwordCredentials); Objects = $servicePrincipals; MissingCreatedDate = ([datetime]'2019-01-01T00:00:00Z').ToUniversalTime() } # Service principals without a creation date count as created on 2019-01-01.
    )

    $report = foreach ($scope in $scopes) {
        $restriction = $scope.Restrictions | Where-Object { $_.restrictionType -eq 'passwordLifetime' } | Select-Object -First 1
        $startDate = $restriction.restrictForAppsCreatedAfterDateTime
        $cutoff = if ($startDate) { ([datetime]$startDate).ToUniversalTime() } else { $null }
        $createdBeforeDate = @($scope.Objects | Where-Object { $createdOn = if ($null -ne $_.createdDateTime) { ([datetime]$_.createdDateTime).ToUniversalTime() } else { $scope.MissingCreatedDate }; $null -ne $cutoff -and ($null -eq $createdOn -or $createdOn -lt $cutoff) }).Count
        $maxLifetime = $restriction.maxLifetime
        $lifetimeDays = $null
        if ($maxLifetime) {
            $lifetimeDays = [System.Xml.XmlConvert]::ToTimeSpan($maxLifetime).TotalDays
        }
        $checks = [ordered]@{
            'Default policy enabled' = $appPolicy.isEnabled -eq $true
            'Restriction enabled' = $restriction.state -eq 'enabled'
            'Lifetime within limit' = $null -ne $lifetimeDays -and $lifetimeDays -le $MaximumLifetimeDays
            'Restriction date reached' = $null -eq $cutoff -or $cutoff -le [datetime]::UtcNow
            'Covers all existing objects' = $createdBeforeDate -eq 0
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{
            Scope = $scope.Name
            State = if ($restriction.state) { $restriction.state } else { 'Not found' }
            CreatedBeforeDate = $createdBeforeDate
            Lifetime = if ($null -ne $lifetimeDays) { "$lifetimeDays days" } else { 'Not set' }
            Failed = $failed -join ', '
            Pass = $failed.Count -eq 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The lifetime of application passwords is limited for applications and service principals.'
    $failText = 'The lifetime of application passwords is not limited as required for applications and service principals.'

    $resultMd = "| Scope | Restriction state | Maximum lifetime | Created before the date | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Scope) | $($row.State) | $($row.Lifetime) | $($row.CreatedBeforeDate) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
