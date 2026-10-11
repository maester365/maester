function Test-MtFixtureFrameworkContosoBl11 {
    <#
    .SYNOPSIS
    Framework fixture: requirement 1.1 of contoso-baseline lists it; it has two Control values of its own, one of which the requirement repeats.
    #>
    [MaesterTest(
        Id                 = 'CONTOSO.BL.1.1',
        Title              = 'Framework fixture CONTOSO.BL.1.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('contoso-policy:P-12', 'nist-800-53-r5:IA-2(1)'),
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
