function Test-MtFixtureFrameworkFxs1 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement R1 of fx-same, which its own suite and the suite beside it both declare.
    #>
    [MaesterTest(
        Id                 = 'FXS.1',
        Title              = 'Framework fixture FXS.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'fx-same:R1',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
