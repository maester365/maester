function Test-MtFixtureWritesStreams {
    <#
    .SYNOPSIS
    Error-path fixture: Writes warning, verbose, debug and information records, then returns $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0018',
        Title    = 'Writes warning, verbose, debug and information records, then returns $true',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Error-path fixture.')][Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Error-path fixture.')][CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Warning 'Fixture warning record'
    Write-Verbose 'Fixture verbose record'
    Write-Debug 'Fixture debug record'
    Write-Information 'Fixture information record'
    Write-Host 'Fixture host record'
    return $true
}
