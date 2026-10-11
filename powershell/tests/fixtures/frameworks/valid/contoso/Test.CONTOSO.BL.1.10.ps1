function Test-MtFixtureFrameworkContosoBl110 {
    <#
    .SYNOPSIS
    Framework fixture: requirement 1.10 of contoso-baseline lists it, with CONTOSO.BL.1.10.EXT.
    #>
    [MaesterTest(
        Id                 = 'CONTOSO.BL.1.10',
        Title              = 'Framework fixture CONTOSO.BL.1.10',
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
