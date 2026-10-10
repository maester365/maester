function Test-MtFixtureInvestigateThenThrows {
    <#
    .SYNOPSIS
    Error-path fixture: -Investigate, then throws.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0019',
        Title    = '-Investigate, then throws',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Error-path fixture.')][CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -Result 'Partial data; review manually.' -Investigate
    throw 'Second page of results failed'
}
