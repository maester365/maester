function Test-MtCisExchangeModernAuthentication {
    <#
    .SYNOPSIS
        Checks that modern authentication is enabled for Exchange Online.

    .DESCRIPTION
        Checks the Exchange Online organisation configuration and passes when OAuth2 client profile (modern authentication) is enabled, which allows clients to use MFA and Conditional Access.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.5.1, L1)

    .EXAMPLE
        Test-MtCisExchangeModernAuthentication

        Returns true if modern authentication is enabled in Exchange Online.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.5.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.5.1',
        Title = 'Ensure modern authentication for Exchange Online is enabled',
        Product = 'exchange',
        Feature = 'client-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1110.003'),
        Control = ('cis-m365:6.5.1', 'nist-800-53-r5:IA-2'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $orgConfig = Get-MtExo -Request OrganizationConfig

    $checks = @(
        [pscustomobject]@{ Setting = 'OAuth2ClientProfileEnabled'; Value = $(if ($null -eq ($orgConfig.OAuth2ClientProfileEnabled)) { 'Not found' } else { $orgConfig.OAuth2ClientProfileEnabled }); Pass = [bool]($orgConfig.OAuth2ClientProfileEnabled -eq $true) }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Modern authentication is enabled for Exchange Online.'
    $failText = 'Modern authentication is not enabled for Exchange Online.'

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
