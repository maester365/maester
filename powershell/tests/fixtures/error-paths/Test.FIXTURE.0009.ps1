function Test-MtFixtureNonTerminatingErrorThenTrue {
    <#
    .SYNOPSIS
    Error-path fixture: Write-Error (non-terminating), then returns $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0009',
        Title    = 'Write-Error (non-terminating), then returns $true',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Error 'One user could not be read; continuing.'
    return $true
}
