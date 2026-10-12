function Test-MtFixtureFrameworkContosoBl110Ext {
    <#
    .SYNOPSIS
    Framework fixture: the second test whose Control names requirement 1.10 of contoso-baseline.
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
        Control            = 'contoso-baseline:1.10',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
