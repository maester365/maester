function Test-MtFixtureFrameworkContosoBl110 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement 1.10 of contoso-baseline, as CONTOSO.BL.1.10.EXT does.
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
        Control            = 'contoso-baseline:1.10',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
