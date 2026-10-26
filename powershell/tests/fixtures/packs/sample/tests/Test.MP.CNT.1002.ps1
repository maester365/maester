function Test-CntSampleAlwaysTrue {
    <#
    .SYNOPSIS
    A pack test that needs no connection.
    #>
    [MaesterTest(
        Id       = 'MP.CNT.1002',
        Title    = 'A pack test that needs no service',
        Severity = 'Info'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $true
}
