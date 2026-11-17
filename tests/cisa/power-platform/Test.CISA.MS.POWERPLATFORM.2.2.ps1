function Test-MtCisaPowerPlatformNonDefaultEnvironmentDlp {
    <#
    .SYNOPSIS
    Checks that non-default Power Platform environments have at least one DLP policy.

    .DESCRIPTION
    Follows the ScubaGear audit for MS.POWERPLATFORM.2.2v1: a DLP policy applies to all environments, or every non-default environment is covered by at least one policy.

    .EXAMPLE
    Test-MtCisaPowerPlatformNonDefaultEnvironmentDlp

    Returns true when every non-default environment is covered by a DLP policy.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPowerPlatformNonDefaultEnvironmentDlp
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERPLATFORM.2.2',
        Title              = 'Non-default environments SHOULD have at least one DLP policy.',
        Product            = 'power-platform',
        Feature            = 'data-policies',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = ('T1567', 'T1048'),
        Control            = 'cisa-scuba:MS.POWERPLATFORM.2.2',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm',
        Contributor        = 'earbona23'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPowerPlatformDlpPolicyScope -Scope NonDefaultEnvironment
}
