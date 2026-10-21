function Test-MtCisPhishingResistantMfaForAdministrators {
    <#
    .SYNOPSIS
        Checks that a Conditional Access policy requires the phishing-resistant authentication strength for the administrative roles.

    .DESCRIPTION
        Checks that at least one enabled Conditional Access policy requires an authentication strength made of exactly the phishing-resistant methods (Windows Hello for Business, FIDO2 security key and certificate-based authentication) for the administrative roles in all cloud apps.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.2.5, L2)

       Checks that at least one enabled Conditional Access policy requires an authentication strength whose allowed combinations contain one or more phishing-resistant methods and no other methods for the administrative roles in all cloud apps.
        Test-MtCisPhishingResistantMfaForAdministrators

        Returns true if an enabled policy requires phishing-resistant MFA for the administrative roles.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.2.5
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.2.5',
        Title = 'Ensure ''Phishing-resistant MFA strength'' is required for Administrators',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1111'),
        Control = ('cis-m365:5.2.2.5', 'nist-800-53-r5:IA-2(1)', 'nist-800-53-r5:IA-2(8)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Conditional Access policies...'
    $policies = Get-MtConditionalAccessPolicy
    $phishingResistantMethods = @('windowsHelloForBusiness', 'fido2', 'x509CertificateMultiFactor')

    $candidates = @($policies | Where-Object { $_.grantControls.authenticationStrength.id -and (@($_.conditions.signInRiskLevels).Count -eq 0 -and @($_.conditions.userRiskLevels).Count -eq 0) })

    $report = foreach ($policy in $candidates) {
        $problems = @(Get-MtCisConditionalAccessScopeProblem -Policy $policy -Users AdministratorRoles)
        $grantProblems = @(Get-MtCisConditionalAccessGrantProblem -Policy $policy)
        $allowed = @($policy.grantControls.authenticationStrength.allowedCombinations)
        $otherMethods = @($allowed | Where-Object { $phishingResistantMethods -notcontains $_ })
        $checks = [ordered]@{
            'Scope covers the required users and apps' = $problems.Count -eq 0
            'Phishing-resistant strength only' = $allowed.Count -gt 0 -and $otherMethods.Count -eq 0
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
    $passText = 'An enabled Conditional Access policy requires phishing-resistant MFA for the administrative roles.'
    $failText = if ($candidates.Count -eq 0) { 'No Conditional Access policy that uses an authentication strength was found.' } else { 'No enabled Conditional Access policy requires phishing-resistant MFA for all the administrative roles.' }

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
