function Test-MtCheckMT1004 {
    <#
    .SYNOPSIS
    At least one Conditional Access policy is configured with All Apps and All Users.

    .DESCRIPTION
    Runs the shared check Test-MtCaAllAppsExists.
    #>
    [MaesterTest(
        Id = 'MT.1004',
        Title = 'At least one Conditional Access policy is configured with All Apps and All Users.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.004',
        Service = 'Graph',
        Author = 'merill',
        Contributor = 'f-bader'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCaAllAppsExists
    if ($null -eq $result) { return $null }
    return $result
}
