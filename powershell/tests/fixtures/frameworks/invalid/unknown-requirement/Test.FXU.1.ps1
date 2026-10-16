function Test-MtFixtureFrameworkFxu1 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement R1 of fx-unknown.
    #>
    [MaesterTest(
        Id                 = 'FXU.1',
        Title              = 'Framework fixture FXU.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'fx-unknown:R1',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
