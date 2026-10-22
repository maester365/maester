function Test-MtCisGeographicAccessControl {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy blocks sign-ins from locations from untrusted locations.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy blocks access for all users and all cloud apps, includes either all locations or only untrusted named locations (countries, or IP ranges not marked trusted), and excludes AllTrusted or at least one trusted IP named location. A policy that includes only selected locations also needs this trusted-location exclusion.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.15, L2)

    .EXAMPLE
        Test-MtCisGeographicAccessControl

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
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Control = ('cis-m365:5.2.2.15', 'nist-800-53-r5:AC-3'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    Write-Verbose 'Getting named locations...'
    $locations = Invoke-MtGraphRequest -RelativeUri 'identity/conditionalAccess/namedLocations'
    # Country locations and IP locations that are not marked trusted can be blocked.
    $untrustedIds = @($locations | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.countryNamedLocation' -or ($_.'@odata.type' -eq '#microsoft.graph.ipNamedLocation' -and $_.isTrusted -ne $true) } | ForEach-Object { $_.id })
    $trustedIds = @(Get-MtTrustedNamedLocationId) + 'AllTrusted'

    $candidates = @($policies | Where-Object { @($_.conditions.locations.excludeLocations).Count -gt 0 -or @($_.conditions.locations.includeLocations).Count -gt 0 })

    $report = foreach ($policy in $candidates) {
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AllUsers -TargetedCondition Locations)
        $grantProblems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $includeLocations = @($policy.conditions.locations.includeLocations | Where-Object { $_ })
        $excludeLocations = @($policy.conditions.locations.excludeLocations | Where-Object { $_ })
        $hasTrustedExclusion = @($excludeLocations | Where-Object { $trustedIds -contains $_ }).Count -gt 0
        $allExcept = $includeLocations -contains 'All' -and $hasTrustedExclusion
        $onlyUntrusted = $includeLocations.Count -gt 0 -and @($includeLocations | Where-Object { $untrustedIds -notcontains $_ }).Count -eq 0 -and $hasTrustedExclusion
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Location condition covers the required locations' = $allExcept -or $onlyUntrusted
            'Block access' = @($policy.grantControls.builtInControls) -contains 'block'
            'Grant controls combine as required' = $grantProblems.Count -eq 0
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $details = @($problems) + @($grantProblems)
        $failedText = $failed -join ', '
        if ($details.Count -gt 0) { $failedText += " ($($details -join '; '))" }
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failedText; Pass = $failed.Count -eq 0 }
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
