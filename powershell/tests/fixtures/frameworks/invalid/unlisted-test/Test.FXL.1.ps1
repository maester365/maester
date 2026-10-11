function Test-MtFixtureFrameworkFxl1 {
    <#
    .SYNOPSIS
    Framework fixture: the framework file lists it.
    #>
    [MaesterTest(
        Id                 = 'FXL.1',
        Title              = 'Framework fixture FXL.1',
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
