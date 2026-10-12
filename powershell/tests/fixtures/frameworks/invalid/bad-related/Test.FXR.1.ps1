function Test-MtFixtureFrameworkFxr1 {
    <#
    .SYNOPSIS
    Framework fixture: its Control names requirement R1 of fx-related, whose file has Related references that are not controls.
    #>
    [MaesterTest(
        Id                 = 'FXR.1',
        Title              = 'Framework fixture FXR.1',
        Product            = 'entra',
        Feature            = 'conditional-access',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'fx-related:R1',
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
