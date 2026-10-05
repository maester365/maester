function Test-MtFixtureStatementTerminatingThenTrue {
    <#
    .SYNOPSIS
    Error-path fixture: Method call on $null, then returns $true.
    #>
    [MaesterTest(
        Id       = 'FIXTURE.0008',
        Title    = 'Method call on $null, then returns $true',
        Severity = 'Info',
        Category = 'Fixture/ErrorPath',
        Tag      = ('Fixture', 'ErrorPath')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = $null
    $count = $policies.GetEnumerator()
    Write-Verbose "Enumerated $count"
    return $true
}
