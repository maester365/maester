function Test-MtFixtureInvestigateReturnsNull {
    <#
    .SYNOPSIS
    Error-path fixture: -Investigate, then returns $null.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0013',
        Title    = '-Investigate, then returns $null',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -Result 'Review manually.' -Investigate
    return $null
}
