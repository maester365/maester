function Test-MtFixtureFrameworkContosoOther1 {
    <#
    .SYNOPSIS
    Framework fixture: its ID has the prefix of no framework of the suite.
    #>
    [MaesterTest(
        Id                 = 'CONTOSO.OTHER.1',
        Title              = 'Framework fixture CONTOSO.OTHER.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('contoso-policy:P-1'),
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
