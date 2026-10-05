function Test-MtFixtureReturnsNull {
    <#
    .SYNOPSIS
    Error-path fixture: Returns $null with no skip and no -Investigate.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0003',
        Title    = 'Returns $null with no skip and no -Investigate',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -Result 'Nothing to evaluate.'
    return $null
}
