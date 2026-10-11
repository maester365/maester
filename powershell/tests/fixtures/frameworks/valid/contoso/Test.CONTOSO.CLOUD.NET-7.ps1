function Test-MtFixtureFrameworkContosoCloudNet7 {
    <#
    .SYNOPSIS
    Framework fixture: requirement NET-7 of contoso-cloud, the second framework of the suite, lists it.
    #>
    [MaesterTest(
        Id                 = 'CONTOSO.CLOUD.NET-7',
        Title              = 'Framework fixture CONTOSO.CLOUD.NET-7',
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
