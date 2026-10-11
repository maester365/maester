function Test-MtCheckMT1050 {
    <#
    .SYNOPSIS
    Apps with high-risk permissions having a direct path to Global Administrator

    .DESCRIPTION
    Runs the shared check Test-MtHighRiskAppPermissions with -AttackPath 'Direct'.
    #>
    [MaesterTest(
        Id = 'MT.1050',
        Title = 'Apps with high-risk permissions having a direct path to Global Administrator',
        Product = 'entra',
        Feature = 'app-consent',
        Area = 'applications',
        ResourceType = 'ServicePrincipal',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1098.001', 'T1098.003'),
        Service = 'Graph',
        Lifecycle = 'Preview',
        LongRunning,
        Author = 'HenrikPiecha',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtHighRiskAppPermissions -AttackPath 'Direct'
    if ($null -eq $result) { return $null }
    return $result
}
