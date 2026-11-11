function Test-MtCisaTeamsThirdPartyApps {
    <#
    .SYNOPSIS
    Checks that third-party Teams apps are restricted to an agency-approved set.

    .DESCRIPTION
    Uses the unified Teams org-wide setting when available, and otherwise evaluates every legacy app permission
    policy using ScubaGear's fallback condition.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.5.2',
        Title              = 'Agencies SHOULD only allow installation of third-party applications approved by the agency.',
        Product            = 'teams',
        Feature            = 'apps',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = ('T1195', 'T1528'),
        Control            = 'cisa-scuba:MS.TEAMS.5.2',
        Service            = ('Graph', 'Teams'),
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test assesses every third-party app category setting.')]
    [OutputType([bool])]
    param()

    return Test-MtCisaTeamsAppControl -SettingName 'GlobalApp' -AppType 'Third-party'
}
