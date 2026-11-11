function Test-MtCisaTeamsMicrosoftApps {
    <#
    .SYNOPSIS
    Checks that Microsoft apps in Teams are restricted to an agency-approved set.

    .DESCRIPTION
    Uses the unified Teams org-wide setting when available, and otherwise evaluates every legacy app permission
    policy using ScubaGear's fallback condition.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.5.1',
        Title              = 'Agencies SHOULD only allow installation of Microsoft applications approved by the agency.',
        Product            = 'teams',
        Feature            = 'apps',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1195',
        Control            = 'cisa-scuba:MS.TEAMS.5.1',
        Service            = ('Graph', 'Teams'),
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test assesses every Microsoft app category setting.')]
    [OutputType([bool])]
    param()

    return Test-MtCisaTeamsAppControl -SettingName 'DefaultApp' -AppType 'Microsoft'
}
