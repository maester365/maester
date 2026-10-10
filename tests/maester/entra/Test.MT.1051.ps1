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
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('App', 'Entra', 'Graph', 'Maester'),
        Preview,
        LongRunning,
        Service = 'Graph',
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
