function Test-MtCisSystemPreferredMfa {
    <#
    .SYNOPSIS
        Checks that system-preferred multifactor authentication is enabled for all users.

    .DESCRIPTION
        Checks that system-preferred MFA is enabled and includes all users, so that sign-in prompts for the most secure method the user has registered instead of a weaker default such as SMS.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.6, L1)

    .EXAMPLE
        Test-MtCisSystemPreferredMfa

        Returns true if system-preferred MFA is enabled for all users.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.6
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.6',
        Title = 'Ensure system-preferred multifactor authentication is enabled',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1111',
        Control = ('cis-m365:5.2.3.6', 'nist-800-53-r5:IA-2'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the authentication methods policy...'
    $policy = Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy' -ApiVersion beta -DisableCache

    $preferences = $policy.systemCredentialPreferences
    $state = "$($preferences.state)"
    $targets = @($preferences.includeTargets.id) -join ', '

    $checks = @(
        [pscustomobject]@{ Setting = 'State'; Value = $(if ($state) { $state } else { 'Not found' }); Pass = $state -eq 'enabled' }
        [pscustomobject]@{ Setting = 'Included targets'; Value = $(if ($targets) { $targets } else { 'Not found' }); Pass = @($preferences.includeTargets.id) -contains 'all_users' }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'System-preferred multifactor authentication is enabled for all users.'
    $failText = 'System-preferred multifactor authentication is not enabled for all users.'
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
