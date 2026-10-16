function Test-MtCisMfaForAdministrativeRoles {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires MFA for the administrative roles in all cloud apps.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy requires multifactor authentication or an authentication strength for a defined set of administrative directory roles in all cloud apps. Policies that apply only to risky sign-ins are not counted because they leave gaps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.1, L1)

    .EXAMPLE
        Test-MtCisMfaForAdministrativeRoles

        Returns true if an enabled policy requires MFA for all the listed administrative roles.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.1',
        Title = 'Ensure multifactor authentication is enabled for all users in administrative roles',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1110.003'),
        Control = ('cis-m365:5.2.2.1', 'nist-800-53-r5:IA-2(1)'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    $requiredRoles = @{
        '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3' = 'Application Administrator'
        'c4e39bd9-1100-46d3-8c65-fb160da0071f' = 'Authentication Administrator'
        'b0f54661-2d74-4c50-afa3-1ec803f12efe' = 'Billing Administrator'
        '158c047a-c907-4556-b7ef-446551a6b5f7' = 'Cloud Application Administrator'
        'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9' = 'Conditional Access Administrator'
        '29232cdf-9323-42fd-ade2-1d097af3e4de' = 'Exchange Administrator'
        '62e90394-69f5-4237-9190-012177145e10' = 'Global Administrator'
        'f2ef992c-3afb-46b9-b7cf-a126ee74c451' = 'Global Reader'
        '729827e3-9c14-49f7-bb1b-9608f156bbb8' = 'Helpdesk Administrator'
        '966707d0-3269-4727-9be2-8c3a10f19b9d' = 'Password Administrator'
        '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' = 'Privileged Authentication Administrator'
        'e8611ab8-c189-46e8-94e1-60213ab1f814' = 'Privileged Role Administrator'
        '194ae4cb-b126-40b2-bd5b-6091b380977d' = 'Security Administrator'
        'f28a1f50-f6e7-4571-818b-6a12f2af6b6c' = 'SharePoint Administrator'
        'fe930be7-5e62-47db-91af-98c3a49a38b1' = 'User Administrator'
    }

    $candidates = @($policies | Where-Object { (@($_.grantControls.builtInControls) -contains 'mfa' -or $_.grantControls.authenticationStrength.id) -and (@($_.conditions.signInRiskLevels).Count -eq 0 -and @($_.conditions.userRiskLevels).Count -eq 0) })

    $report = foreach ($policy in $candidates) {
        $includedRoles = @($policy.conditions.users.includeRoles)
        $missingRoles = @($requiredRoles.Keys | Where-Object { $includedRoles -notcontains $_ })
        $checks = [ordered]@{
            'All administrative roles' = $missingRoles.Count -eq 0
            'All applications' = @($policy.conditions.applications.includeApplications) -contains 'All'
            'MFA required' = [bool](@($policy.grantControls.builtInControls) -contains 'mfa' -or $policy.grantControls.authenticationStrength.id)
            'Enabled' = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy requires multifactor authentication for all the administrative roles.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that requires multifactor authentication was found.' } else { 'No enabled Conditional Access policy requires multifactor authentication for all the administrative roles.' }

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
