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
        Product = 'exchange',
        RelatedProduct = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1213', 'T1530', 'T1567'),
        Control = 'cisa-scuba:MS.EXO.8.3',
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Unable to validate 3rd party solutions."
    return $null
}
