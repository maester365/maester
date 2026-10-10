function Test-MtCheckMT1051 {
    <#
    .SYNOPSIS
    Apps with high-risk permissions having an indirect path to Global Administrator

    .DESCRIPTION
    Runs the shared check Test-MtHighRiskAppPermissions with -AttackPath 'Indirect'.
    #>
    [MaesterTest(
        Id = 'MT.1051',
        Title = 'Apps with high-risk permissions having an indirect path to Global Administrator',
        Product = 'entra',
        Severity = 'High',
        Service = 'Graph',
        Lifecycle = 'Preview',
        LongRunning,
        Author = 'HenrikPiecha',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtHighRiskAppPermissions -AttackPath 'Indirect'
    if ($null -eq $result) { return $null }
    return $result
}
