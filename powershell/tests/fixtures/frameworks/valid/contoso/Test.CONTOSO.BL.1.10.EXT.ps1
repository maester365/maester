function Test-MtFixtureFrameworkContosoBl110Ext {
    <#
    .SYNOPSIS
    Framework fixture: the second test of requirement 1.10 of contoso-baseline.
    #>
    [MaesterTest(
        Id                 = 'CONTOSO.BL.1.10.EXT',
        Title              = 'Framework fixture CONTOSO.BL.1.10.EXT',
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
