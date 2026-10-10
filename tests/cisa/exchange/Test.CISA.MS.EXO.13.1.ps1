function Test-MtCisaMailboxAuditing {
    <#
    .SYNOPSIS
    Checks state of mailbox auditing

    .DESCRIPTION
    Mailbox auditing SHALL be enabled.

    .EXAMPLE
    Test-MtCisaMailboxAuditing

    Returns true if mailbox auditing is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaMailboxAuditing
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.13.1',
        Title = 'Mailbox auditing SHALL be enabled.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.13.1'),
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-MtExo -Request OrganizationConfig

    $testResult = (-not $config.AuditDisabled)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has mailbox auditing enabled.`n`n%TestResult%"
        $result = "✅ Pass"
    } else {
        $testResultMarkdown = "Your tenant does not have mailbox auditing enabled.`n`n%TestResult%"
        $result = "❌ Fail"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
