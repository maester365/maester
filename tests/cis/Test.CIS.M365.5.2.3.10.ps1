function Test-MtCisAuthenticatorCompanionAppsDisabled {
    <#
    .SYNOPSIS
        Checks that Microsoft Authenticator functionality in companion applications is disabled.

    .DESCRIPTION
        Checks that the Microsoft Authenticator setting for companion applications is disabled, so that MFA approvals cannot be given from inside another app on the same device that started the sign-in.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.10, L1)

    .EXAMPLE
        Test-MtCisAuthenticatorCompanionAppsDisabled

        Returns true if Microsoft Authenticator on companion applications is disabled.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.10
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.10',
        Title = 'Ensure Microsoft Authenticator on companion applications is disabled',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1111',
        Control = ('cis-m365:5.2.3.10', 'nist-800-53-r5:IA-2'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the authentication methods policy...'
    $policy = Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy' -ApiVersion beta

    $authenticator = @($policy.authenticationMethodConfigurations) | Where-Object { $_.id -eq 'MicrosoftAuthenticator' }
    $state = "$($authenticator.featureSettings.companionAppAllowedState.state)"
    $testResult = $state -eq 'disabled'

    $passText = 'Microsoft Authenticator on companion applications is disabled.'
    $failText = 'Microsoft Authenticator on companion applications is not disabled.'

    $resultMd = "| Setting | State | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| Companion applications | $(if ($state) { $state } else { 'Not found' }) | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
