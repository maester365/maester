function Test-MtFixtureFrameworkFxp1 {
    <#
    .SYNOPSIS
    Framework fixture: the framework file lists it.
    #>
    [MaesterTest(
        Id                 = 'FXP.1',
        Title              = 'Framework fixture FXP.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
