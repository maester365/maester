function Test-MtCisAppPasswordAdditionBlocked {
    <#
    .SYNOPSIS
        Checks that the default app management policy blocks adding password credentials to apps and service principals.

    .DESCRIPTION
        Checks that the default app management policy is enabled and that its password addition restriction is enabled, its restriction date is reached and no application or service principal was created before that date, for both applications and service principals, so that client secrets cannot be added and certificates or federated credentials are used instead.
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
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1098.001',
        Control = ('cis-m365:5.1.5.3', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the default app management policy...'
    $appPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/defaultAppManagementPolicy'

    Write-Verbose 'Getting the applications and service principals...'
    $tenantId = (Invoke-MtGraphRequest -RelativeUri 'organization').id
    $applications = @(Invoke-MtGraphRequest -RelativeUri 'applications?$select=createdDateTime')
    # Managed identities take no passwords, and first-party service principals belong to Microsoft.
    $servicePrincipals = @(Invoke-MtGraphRequest -RelativeUri 'servicePrincipals?$select=createdDateTime,appOwnerOrganizationId,servicePrincipalType' | Where-Object { $_.appOwnerOrganizationId -eq $tenantId -and $_.servicePrincipalType -ne 'ManagedIdentity' })

    $scopes = @(
        [pscustomobject]@{ Name = 'Applications'; Restrictions = @($appPolicy.applicationRestrictions.passwordCredentials); Objects = $applications }
        [pscustomobject]@{ Name = 'Service principals'; Restrictions = @($appPolicy.servicePrincipalRestrictions.passwordCredentials); Objects = $servicePrincipals }
    )

    $report = foreach ($scope in $scopes) {
        $restriction = $scope.Restrictions | Where-Object { $_.restrictionType -eq 'passwordAddition' } | Select-Object -First 1
        $startDate = $restriction.restrictForAppsCreatedAfterDateTime
        $cutoff = if ($startDate) { ([datetime]$startDate).ToUniversalTime() } else { $null }
        $createdBeforeDate = @($scope.Objects | Where-Object { $null -ne $cutoff -and ($null -eq $_.createdDateTime -or ([datetime]$_.createdDateTime).ToUniversalTime() -lt $cutoff) }).Count
        $checks = [ordered]@{
            'Default policy enabled' = $appPolicy.isEnabled -eq $true
            'Restriction enabled' = $restriction.state -eq 'enabled'
            'Restriction date reached' = $null -eq $cutoff -or $cutoff -le [datetime]::UtcNow
            'Covers all existing objects' = $createdBeforeDate -eq 0
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{
            Scope = $scope.Name
            State = if ($restriction.state) { $restriction.state } else { 'Not found' }
            CreatedBeforeDate = $createdBeforeDate
            Lifetime = ''
            Failed = $failed -join ', '
            Pass = $failed.Count -eq 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Adding password credentials is blocked for applications and service principals.'
    $failText = 'Adding password credentials is not blocked for applications and service principals.'

    $resultMd = "| Scope | Restriction state | Created before the date | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Scope) | $($row.State) | $($row.CreatedBeforeDate) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
