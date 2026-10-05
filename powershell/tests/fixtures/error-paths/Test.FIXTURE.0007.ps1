function Test-MtFixtureThrows {
    <#
    .SYNOPSIS
    Error-path fixture: Throws a terminating error.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0007',
        Title    = 'Throws a terminating error',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    throw 'Graph returned 500 Internal Server Error'
}
