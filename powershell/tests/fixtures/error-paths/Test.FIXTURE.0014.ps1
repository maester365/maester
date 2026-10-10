function Test-MtFixtureSkipInsideOwnTryCatch {
    <#
    .SYNOPSIS
    Error-path fixture: Skip raised inside the test's own try/catch.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0014',
        Title    = 'Skip raised inside the test''s own try/catch',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
