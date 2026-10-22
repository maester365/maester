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
        Product = 'exchange',
        Feature = 'mailbox-auditing',
        Area = 'logging-and-detection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1070.008', 'T1098.002', 'T1564.008', 'T1586.002', 'T1685.002'),
        Control = 'cisa-scuba:MS.EXO.13.1',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-MtExo -Request OrganizationConfig

    if ($null -eq $config -or $null -eq $config.AuditDisabled) {
        # AuditDisabled is a negative flag, so -not $null below is $true and the check would
        # report mailbox auditing as enabled for a tenant whose configuration was never read.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

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
