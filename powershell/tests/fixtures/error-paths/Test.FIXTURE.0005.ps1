function Test-MtFixtureReturnsTwoBooleans {
    <#
    .SYNOPSIS
    Error-path fixture: Returns two booleans.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0005',
        Title    = 'Returns two booleans',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Error-path fixture.')][CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Output $true
    return $false
}
