function Test-MtFixtureLeaksPipelineOutput {
    <#
    .SYNOPSIS
    Error-path fixture: Leaks ArrayList.Add output before returning $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0006',
        Title    = 'Leaks ArrayList.Add output before returning $true',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $list = [System.Collections.ArrayList]::new()
    $list.Add('first')
    return $true
}
