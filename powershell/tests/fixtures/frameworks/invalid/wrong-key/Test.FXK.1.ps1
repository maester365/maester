function Test-MtFixtureFrameworkFxk1 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement R1 of fx-key, whose file says it is another framework.
    #>
    [MaesterTest(
        Id                 = 'FXK.1',
        Title              = 'Framework fixture FXK.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'fx-key:R1',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
