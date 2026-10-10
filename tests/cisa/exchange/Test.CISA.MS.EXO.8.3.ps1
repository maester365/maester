function Test-MtCisaDlpAlternate {
    <#
    .SYNOPSIS
    This will always return $null

    .DESCRIPTION
    The selected DLP solution SHOULD offer services comparable to the native DLP solution offered by Microsoft.

    .EXAMPLE
    Test-MtCisaDlpAlternate

    Always will return $null

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaDlpAlternate
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.8.3',
        Title = 'The selected DLP solution SHOULD offer services comparable to the native DLP solution offered by Microsoft.',
        Severity = 'Medium',
        Category = 'CISA',
        Product = 'Exchange Online',
        Tag = ('MS.EXO', 'MS.EXO.8.3'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Unable to validate 3rd party solutions."
    return $null
}
