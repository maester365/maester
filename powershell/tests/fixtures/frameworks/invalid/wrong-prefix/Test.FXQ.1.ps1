function Test-MtFixtureFrameworkFxq1 {
    <#
    .SYNOPSIS
    Framework fixture: the framework file lists it, but its ID does not have the prefix of the framework.
    #>
    [MaesterTest(
        Id                 = 'FXQ.1',
        Title              = 'Framework fixture FXQ.1',
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
