function Test-MtFixtureFrameworkFxm1 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names a requirement of fx-missing, which has no framework file.
    #>
    [MaesterTest(
        Id                 = 'FXM.1',
        Title              = 'Framework fixture FXM.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'fx-missing:R1',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
