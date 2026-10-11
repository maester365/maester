function Test-MtFixtureFrameworkFxr1 {
    <#
    .SYNOPSIS
    Framework fixture: its requirement has Related references that are not written <framework-key>:<control-id>.
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
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
