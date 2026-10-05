function Test-MtFixtureInvestigateReturnsFalse {
    <#
    .SYNOPSIS
    Error-path fixture: -Investigate, then returns $false.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0012',
        Title    = '-Investigate, then returns $false',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -Result 'Two policies overlap; review manually.' -Investigate
    return $false
}
