function Test-MtCisaSmtpAuthentication {
    <#
    .SYNOPSIS
    Checks state of SMTP authentication in Exchange Online.

    .DESCRIPTION
    SMTP authentication SHALL be disabled.

    .EXAMPLE
    Test-MtCisaSmtpAuthentication

    Returns true if SMTP authentication is disabled in Exchange Online.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSmtpAuthentication
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.5.1',
        Title = 'SMTP AUTH SHALL be disabled.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.5.1'),
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-MtExo -Request TransportConfig

    $testResult = $config.SmtpClientAuthenticationDisabled

    $portalLink = "https://admin.exchange.microsoft.com/#/settings"
    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [SMTP Authentication]($portalLink) disabled."
    } else {
        $testResultMarkdown = "Your tenant has [SMTP Authentication]($portalLink) enabled."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
