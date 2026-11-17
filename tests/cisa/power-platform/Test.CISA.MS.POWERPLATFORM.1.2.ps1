function Test-MtCisaPowerPlatformTrialEnvironmentCreation {
    <#
    .SYNOPSIS
    Checks that only administrators can create trial Power Platform environments.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.1.2v1: the tenant setting disableTrialEnvironmentCreationByNonAdminUsers must be true.

    .EXAMPLE
    Test-MtCisaPowerPlatformTrialEnvironmentCreation

    Returns true when trial environment creation is restricted to administrators.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformTrialEnvironmentCreation
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.1.2',
        Title              = 'The ability to create trial environments SHALL be restricted to administrators.',
        Product            = 'power-platform',
        Feature            = 'environments',
        Area               = 'access-control',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'cisa-scuba:MS.POWERPLATFORM.1.2',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformTenantSetting -SettingName 'disableTrialEnvironmentCreationByNonAdminUsers' -SettingTitle 'Trial environment creation is restricted to administrators'
}
