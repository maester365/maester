function Test-MtFixtureSkipNotApplicableNoReturn {
    <#
    .SYNOPSIS
    Error-path fixture: -SkippedBecause NotApplicable with no return after it.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0010',
        Title    = '-SkippedBecause NotApplicable with no return after it',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause NotApplicable
    return = $null
}
