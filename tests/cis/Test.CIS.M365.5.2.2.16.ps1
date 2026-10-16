function Test-MtCisTokenProtection {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy enforces token protection for Exchange, SharePoint and Teams on Windows.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy requires token protection (secure sign-in session) for Exchange Online, SharePoint Online and Microsoft Teams, on Windows desktop clients.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.16, L2)

    .EXAMPLE
        Test-MtCisTokenProtection

        Returns true if an enabled policy enforces token protection for the supported apps on Windows.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.16
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.16',
        Title = 'Ensure Token Protection is enforced for session tokens',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1539', 'T1550.004'),
        Control = ('cis-m365:5.2.2.16', 'nist-800-53-r5:SC-23'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    $requiredApps = @(
        '00000002-0000-0ff1-ce00-000000000000'  # Office 365 Exchange Online
        '00000003-0000-0ff1-ce00-000000000000'  # Office 365 SharePoint Online
        'cc15fd57-2c6c-4117-a88c-83b1d56b4bbe'  # Microsoft Teams Services
    )

    $candidates = @($policies | Where-Object { $_.sessionControls.secureSignInSession.isEnabled })

    $report = foreach ($policy in $candidates) {
        $includedApps = @($policy.conditions.applications.includeApplications)
        $missingApps = @($requiredApps | Where-Object { $includedApps -notcontains $_ })
        $checks = [ordered]@{
            'Users included'                 = [bool](@($policy.conditions.users.includeUsers) -notcontains 'None')
            'Exchange, SharePoint and Teams' = $missingApps.Count -eq 0
            'Windows platform'               = @($policy.conditions.platforms.includePlatforms) -contains 'windows'
            'Desktop clients'                = (@($policy.conditions.clientAppTypes) | Sort-Object) -join ',' -eq 'mobileAppsAndDesktopClients'
            'Token protection enabled'       = $policy.sessionControls.secureSignInSession.isEnabled -eq $true
            'Enabled'                        = $policy.state -eq 'enabled'
        }
        $failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $policy.displayName; State = $policy.state; Failed = $failed -join ', '; Pass = $failed.Count -eq 0 }
    }
    $testResult = @($report | Where-Object { $_.Pass }).Count -gt 0
    $passText = 'An enabled Conditional Access policy enforces token protection for Exchange Online, SharePoint Online and Microsoft Teams.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that uses token protection was found.' } else { 'No enabled Conditional Access policy enforces token protection for Exchange Online, SharePoint Online and Microsoft Teams on Windows.' }

    $resultMd = "| Policy | State | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Name) | $($row.State) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}