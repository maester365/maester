function Test-MtFixtureFrameworkFxk1 {
    <#
    .SYNOPSIS
    Framework fixture: the framework file names another key and another version than the suite.json.
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
        Service            = 'None',
        Author             = 'maester'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return $true
}
