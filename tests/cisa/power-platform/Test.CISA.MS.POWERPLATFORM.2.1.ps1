function Test-MtCisaPowerPlatformDefaultEnvironmentDlp {
    <#
    .SYNOPSIS
    Checks that a DLP policy restricts connector access in the default Power Platform environment.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.2.1v1: at least one DLP policy must apply to the default environment, directly, to all environments, or by excluding only other environments.

    .EXAMPLE
    Test-MtCisaPowerPlatformDefaultEnvironmentDlp

    Returns true when a DLP policy applies to the default environment.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformDefaultEnvironmentDlp
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.2.1',
        Title              = 'A DLP policy SHALL be created to restrict connector access in the default Power Platform environment.',
        Product            = 'power-platform',
        Feature            = 'data-policies',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = ('T1567', 'T1048'),
        Control            = 'cisa-scuba:MS.POWERPLATFORM.2.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformDlpPolicyScope -Scope DefaultEnvironment
}
