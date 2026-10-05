function Test-MtFixtureLongSleep {
    <#
    .SYNOPSIS
    Error-path fixture: Sleeps 30 seconds, then returns $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0017',
        Title    = 'Sleeps 30 seconds, then returns $true',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Start-Sleep -Seconds 30
    return $true
}
