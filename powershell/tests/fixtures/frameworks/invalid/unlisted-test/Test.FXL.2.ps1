function Test-MtFixtureFrameworkFxl2 {
    <#
    .SYNOPSIS
    Framework fixture: it has the prefix of fx-unlisted, and the framework file does not list it.
    #>
    [MaesterTest(
        Id                 = 'FXL.2',
        Title              = 'Framework fixture FXL.2',
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
