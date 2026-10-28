function Test-MtCisWeakAuthenticationMethodsDisabled {
    <#
    .SYNOPSIS
        Checks if SMS and voice call authentication methods are disabled in the tenant.

    .DESCRIPTION
        SMS and voice call authentication methods should be disabled.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.5, L1)

    .EXAMPLE
        Test-MtCisWeakAuthenticationMethodsDisabled

        Returns true if weak authentication methods are disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisWeakAuthenticationMethodsDisabled
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.5',
        Title = 'Ensure weak authentication methods are disabled',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1566.002', 'T1621', 'T1111'),
        Control = ('cis-m365:5.2.3.5', 'nist-800-53-r5:CM-7', 'nist-800-53-r5:IA-5'),
        Service = 'Graph',
        Author = 'oed-metzb',
        Contributor = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting settings...'
    $settings = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -DisableCache

    Write-Verbose 'Executing checks'
    $checkSms = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Sms" }).State -eq "disabled"
    $checkVoice = ($settings.authenticationMethodConfigurations | Where-Object { $_.id -eq "Voice" }).State -eq "disabled"

    $testResult = $checkSms -and $checkVoice

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant settings comply with CIS recommendations.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant settings do not comply with CIS recommendations.`n`n%TestResult%"
    }

    $resultMd = "| Authentication method | Result |`n"
    $resultMd += "| --- | --- |`n"

    if ($checkSms) {
        $checkSmsResult = '✅ Pass'
    }
    else {
        $checkSmsResult = '❌ Fail'
    }

    if ($checkVoice) {
        $checkVoiceResult = '✅ Pass'
    }
    else {
        $checkVoiceResult = '❌ Fail'
    }

    $resultMd += "| SMS | $checkSmsResult |`n"
    $resultMd += "| Voice call | $checkVoiceResult |`n"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
