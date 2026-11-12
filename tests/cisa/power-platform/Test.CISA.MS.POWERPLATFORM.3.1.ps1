function Test-MtCisaPowerPlatformTenantIsolationEnabled {
    <#
    .SYNOPSIS
    Checks that Power Platform tenant isolation is enabled.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.3.1v1: the tenant isolation policy must exist and isDisabled must be false.

    .EXAMPLE
    Test-MtCisaPowerPlatformTenantIsolationEnabled

    Returns true when Power Platform tenant isolation is enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformTenantIsolationEnabled
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.3.1',
        Title              = 'Power Platform tenant isolation SHALL be enabled.',
        Product            = 'power-platform',
        Feature            = 'tenant-isolation',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = 'cisa-scuba:MS.POWERPLATFORM.3.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformTenantIsolation
}
