function Test-MtFixtureFrameworkFxm1 {
    <#
    .SYNOPSIS
    Framework fixture: its suite declares the framework fx-missing, which has no file.
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
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
