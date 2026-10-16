function Test-MtCisSmtpAuthDisabled {
    <#
    .SYNOPSIS
        Checks that SMTP client authentication is disabled for the organization.

    .DESCRIPTION
        Checks the Exchange Online transport configuration and passes when SMTP AUTH is disabled organisation-wide. SMTP AUTH uses basic authentication and cannot use MFA.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.5.4, L1)

    .EXAMPLE
        Test-MtCisSmtpAuthDisabled

        Returns true if SMTP AUTH is disabled for the organization.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.5.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.5.4',
        Title = 'Ensure SMTP AUTH is disabled',
        Product = 'exchange',
        Feature = 'client-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1110.003'),
        Control = ('cis-m365:6.5.4', 'nist-800-53-r5:CM-7'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $transportConfig = Get-MtExo -Request TransportConfig

    $checks = @(
        [pscustomobject]@{ Setting = 'SmtpClientAuthenticationDisabled'; Value = $(if ($null -eq ($transportConfig.SmtpClientAuthenticationDisabled)) { 'Not found' } else { $transportConfig.SmtpClientAuthenticationDisabled }); Pass = [bool]($transportConfig.SmtpClientAuthenticationDisabled -eq $true) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'SMTP AUTH is disabled for the organization.'
    $failText = 'SMTP AUTH is not disabled for the organization.'

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