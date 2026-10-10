function Test-MtFixtureReturnsTrue {
    <#
    .SYNOPSIS
    Error-path fixture: Returns $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0001',
        Title    = 'Returns $true',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
