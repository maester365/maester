function Test-MtCisGeographicAccessControls {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy blocks sign-ins from locations other than the trusted named locations.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy blocks access for all users and all cloud apps where all locations are included and the excluded locations are all trusted named locations, so that sign-ins from anywhere else are blocked.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.15, L2)

    .EXAMPLE
        Test-MtCisGeographicAccessControls

        Returns true if an enabled policy blocks sign-ins from outside the trusted locations.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.15
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.15',
        Title = 'Ensure exclusionary geographic access controls are utilized',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.2.2.15', 'nist-800-53-r5:AC-3'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    Write-Verbose 'Getting named locations...'
    $locations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations' -DisableCache
    $trustedIds = @($locations | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.ipNamedLocation' -and $_.isTrusted } | ForEach-Object { $_.id }) + 'AllTrusted'

    $candidates = @($policies | Where-Object { @($_.conditions.locations.excludeLocations).Count -gt 0 -or @($_.conditions.locations.includeLocations).Count -gt 0 })

    $report = foreach ($policy in $candidates) {
        $includeLocations = @($policy.conditions.locations.includeLocations)
        $excludeLocations = @($policy.conditions.locations.excludeLocations)
        $untrustedExcluded = @($excludeLocations | Where-Object { $trustedIds -notcontains $_ })
        $checks = [ordered]@{
            'All users' = @($policy.conditions.users.includeUsers) -contains 'All'
            'All applications' = @($policy.conditions.applications.includeApplications) -contains 'All'
            'All locations included' = $includeLocations -contains 'All'
            'Locations excluded' = $excludeLocations.Count -gt 0
            'Only trusted locations excluded' = $untrustedExcluded.Count -eq 0
            'Block access' = @($policy.grantControls.builtInControls) -contains 'block'
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy blocks sign-ins from outside the trusted locations.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that uses a location condition was found.' } else { 'No enabled Conditional Access policy blocks sign-ins from outside the trusted locations.' }

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