function Test-MtFixtureFrameworkContosoBl11 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement 1.1 of contoso-baseline between two other controls, one of which the requirement repeats as Related.
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
        Control            = ('contoso-policy:P-12', 'contoso-baseline:1.1', 'nist-800-53-r5:IA-2(1)'),
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
