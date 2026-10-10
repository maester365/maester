function Test-MtFixtureReturnsFalse {
    <#
    .SYNOPSIS
    Error-path fixture: Returns $false.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0002',
        Title    = 'Returns $false',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $false
}
