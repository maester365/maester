function Test-MtFixtureReturnsString {
    <#
    .SYNOPSIS
    Error-path fixture: Returns a string instead of a boolean.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0004',
        Title    = 'Returns a string instead of a boolean',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return 'True'
}
