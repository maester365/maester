function Test-MtFixtureSkipBecauseError {
    <#
    .SYNOPSIS
    Error-path fixture: -SkippedBecause Error with the caught record.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0011',
        Title    = '-SkippedBecause Error with the caught record',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        throw 'Exchange cmdlet failed'
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
