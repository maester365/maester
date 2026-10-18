function Test-MtCisEmailOtpAuthenticationMethodDisabled {
    <#
    .SYNOPSIS
        Checks that the email one-time passcode authentication method is disabled.

    .DESCRIPTION
        The Email OTP method sends a passcode to an email inbox. Anyone who controls or intercepts that inbox can
        sign in as the account that the passcode was sent to.
        This check reads the authentication methods policy and passes when the Email method is disabled.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.7, L2)

    .EXAMPLE
        Test-MtCisEmailOtpAuthenticationMethodDisabled

        Returns true if the Email OTP authentication method is disabled.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.7
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.7',
        Title = 'Ensure the email OTP authentication method is disabled',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1111'),
        Control = ('cis-m365:5.2.3.7', 'nist-800-53-r5:CM-7', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the authentication methods policy...'
    $policy = Invoke-MtGraphRequest -RelativeUri 'policies/authenticationMethodsPolicy'

    $emailMethod = @($policy.authenticationMethodConfigurations) | Where-Object { $_.id -eq 'Email' }
    $state = $emailMethod.state
    $testResult = $state -eq 'disabled'

    if ($testResult) {
        $testResultMarkdown = "Well done. The Email OTP authentication method is disabled.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The Email OTP authentication method is not disabled.`n`n%TestResult%"
    }

    if ([string]::IsNullOrEmpty($state)) {
        $state = 'Not found'
    }

    $resultMd = "| Authentication method | State | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| Email OTP | $state | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
