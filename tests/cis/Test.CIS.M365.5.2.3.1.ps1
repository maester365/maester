function Test-MtCisAuthenticatorFatigueProtection {
    <#
    .SYNOPSIS
        Checks that Microsoft Authenticator shows application and location context for all users.

    .DESCRIPTION
        Checks that the Microsoft Authenticator method is enabled for all users and that it displays the application name and the sign-in location in notifications, which helps users reject push requests they did not start (MFA fatigue).
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.1, L1)

    .EXAMPLE
        Test-MtCisAuthenticatorFatigueProtection

        Returns true if Microsoft Authenticator shows application and location information to all users.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.1',
        Title = 'Ensure Microsoft Authenticator is configured to protect against MFA fatigue',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1621',
        Control = ('cis-m365:5.2.3.1', 'nist-800-53-r5:IA-2'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the authentication methods policy...'
    $policy = Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy' -ApiVersion beta

    $authenticator = @($policy.authenticationMethodConfigurations) | Where-Object { $_.id -eq 'MicrosoftAuthenticator' }
    $appInfo = $authenticator.featureSettings.displayAppInformationRequiredState
    $locationInfo = $authenticator.featureSettings.displayLocationInformationRequiredState

    $checks = @(
        [pscustomobject]@{ Setting = 'Microsoft Authenticator method'; Value = "$($authenticator.state)"; Pass = $authenticator.state -eq 'enabled' }
        [pscustomobject]@{ Setting = 'Method targets all users'; Value = "$(@($authenticator.includeTargets.id) -join ', ')"; Pass = @($authenticator.includeTargets.id) -contains 'all_users' }
        [pscustomobject]@{ Setting = 'Show application name'; Value = "$($appInfo.state)"; Pass = $appInfo.state -eq 'enabled' }
        [pscustomobject]@{ Setting = 'Show application name targets all users'; Value = "$(@($appInfo.includeTarget.id) -join ', ')"; Pass = @($appInfo.includeTarget.id) -contains 'all_users' }
        [pscustomobject]@{ Setting = 'Show geographic location'; Value = "$($locationInfo.state)"; Pass = $locationInfo.state -eq 'enabled' }
        [pscustomobject]@{ Setting = 'Show geographic location targets all users'; Value = "$(@($locationInfo.includeTarget.id) -join ', ')"; Pass = @($locationInfo.includeTarget.id) -contains 'all_users' }
    )
    foreach ($check in $checks) {
        if ([string]::IsNullOrEmpty($check.Value)) {
            $check.Value = 'Not found'
        }
    }
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Microsoft Authenticator shows the application name and sign-in location to all users.'
    $failText = 'Microsoft Authenticator does not show the application name and sign-in location to all users.'
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
