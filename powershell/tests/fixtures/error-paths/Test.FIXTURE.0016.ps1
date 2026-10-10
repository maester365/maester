function Test-MtFixtureExit {
    <#
    .SYNOPSIS
    Error-path fixture: exit inside the test function.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0016',
        Title    = 'exit inside the test function',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    exit 1
}
