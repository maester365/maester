function Test-MtCisaPowerPlatformPowerPagesCreation {
    <#
    .SYNOPSIS
    Checks that only administrators can create Power Pages sites.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.5.1v1: the tenant setting disablePortalsCreationByNonAdminUsers must be true.

    .EXAMPLE
    Test-MtCisaPowerPlatformPowerPagesCreation

    Returns true when Power Pages site creation is restricted to administrators.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformPowerPagesCreation
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.5.1',
        Title              = 'The ability to create Power Pages sites SHOULD be restricted to administrators.',
        Product            = 'power-platform',
        Feature            = 'power-pages',
        Area               = 'access-control',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1190',
        Control            = 'cisa-scuba:MS.POWERPLATFORM.5.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformTenantSetting -SettingName 'disablePortalsCreationByNonAdminUsers' -SettingTitle 'Power Pages site creation is restricted to administrators'
}
