function Test-MtFixtureFrameworkFxt1 {
    <#
    .SYNOPSIS
    Framework fixture: two requirements of the framework file list it.
    #>
    [MaesterTest(
        Id                 = 'FXT.1',
        Title              = 'Framework fixture FXT.1',
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
