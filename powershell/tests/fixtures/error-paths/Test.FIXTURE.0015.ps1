function Test-MtFixtureBreakAtTopLevel {
    <#
    .SYNOPSIS
    Error-path fixture: break at the top level of the function.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0015',
        Title    = 'break at the top level of the function',
        Severity = 'Info',
        Feature = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($true) {
        break
    }
    return $true
}
