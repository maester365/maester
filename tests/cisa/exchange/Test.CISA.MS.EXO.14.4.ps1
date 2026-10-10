function Test-MtCisaSpamAlternative {
    <#
    .SYNOPSIS
    Checks state of spam filter

    .DESCRIPTION
    If a third-party party filtering solution is used, the solution SHOULD offer services comparable to the native spam filtering offered by Microsoft.

    .EXAMPLE
    Test-MtCisaSpamAlternative

    Always returns $null

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamAlternative
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.14.4',
        Title = 'If a third-party party filtering solution is used, the solution SHOULD offer services comparable to the native spam filtering offered by Microsoft.',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.14.4'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Unable to validate 3rd party solutions."
    return $null
}
