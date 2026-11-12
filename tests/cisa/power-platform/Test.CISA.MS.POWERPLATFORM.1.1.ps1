function Test-MtCisaPowerPlatformEnvironmentCreation {
    <#
    .SYNOPSIS
    Checks that only administrators can create production and sandbox Power Platform environments.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.1.1v1: the tenant setting disableEnvironmentCreationByNonAdminUsers must be true.

    .EXAMPLE
    Test-MtCisaPowerPlatformEnvironmentCreation

    Returns true when production and sandbox environment creation is restricted to administrators.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformEnvironmentCreation
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.1.1',
        Title              = 'The ability to create production and sandbox environments SHALL be restricted to administrators.',
        Product            = 'power-platform',
        Feature            = 'environments',
        Area               = 'access-control',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = ('T1567', 'T1048'),
        Control            = 'cisa-scuba:MS.POWERPLATFORM.1.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformTenantSetting -SettingName 'disableEnvironmentCreationByNonAdminUsers' -SettingTitle 'Production and sandbox environment creation is restricted to administrators'
}
