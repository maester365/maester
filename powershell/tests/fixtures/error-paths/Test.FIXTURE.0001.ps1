function Test-MtFixtureReturnsTrue {
    <#
    .SYNOPSIS
    Error-path fixture: Returns $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0001',
        Title    = 'Returns $true',
        Severity = 'Info',
        Feature = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
