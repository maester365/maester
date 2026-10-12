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
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'ServicePrincipal',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1098.001', 'T1098.003'),
        Control = 'nist-800-53-r5:AC-6',
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
