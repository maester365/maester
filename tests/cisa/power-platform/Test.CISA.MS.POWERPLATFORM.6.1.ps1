function Test-MtCisaPowerPlatformShareWithEveryoneDisabled {
    <#
    .SYNOPSIS
    Checks that the Power Apps "Share with everyone" feature is disabled.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.6.1v1: the tenant setting powerPlatform.powerApps.disableShareWithEveryone must be true.

    .EXAMPLE
    Test-MtCisaPowerPlatformShareWithEveryoneDisabled

    Returns true when Power Apps sharing with everyone is disabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformShareWithEveryoneDisabled
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.6.1',
        Title              = 'The "Share with everyone" feature SHOULD be disabled.',
        Product            = 'power-platform',
        Feature            = 'power-apps',
        Area               = 'access-control',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = ('T1078.004', 'T1098.007'),
        Control            = 'cisa-scuba:MS.POWERPLATFORM.6.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformTenantSetting -SettingName 'powerPlatform.powerApps.disableShareWithEveryone' -SettingTitle 'Power Apps sharing with everyone is disabled'
}
