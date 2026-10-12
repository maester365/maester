function Test-MtFixtureFrameworkFxu2 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement R9 of fx-unknown, which the framework file does not have.
    #>
    [MaesterTest(
        Id                 = 'FXU.2',
        Title              = 'Framework fixture FXU.2',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'fx-unknown:R9',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
