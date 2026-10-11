function Test-MtFixtureFrameworkFxu1 {
    <#
    .SYNOPSIS
    Framework fixture: the framework file also names FXU.404, which does not exist.
    #>
    [MaesterTest(
        Id                 = 'FXU.1',
        Title              = 'Framework fixture FXU.1',
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
