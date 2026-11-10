function Test-MtCisaTeamsCustomApps {
    <#
    .SYNOPSIS
    Checks that custom Teams apps are restricted to an agency-approved set.

    .DESCRIPTION
    Uses the unified Teams org-wide setting when available, and otherwise evaluates every legacy app permission
    policy using ScubaGear's fallback condition.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.5.3',
        Title              = 'Agencies SHOULD only allow installation of custom applications approved by the agency.',
        Product            = 'teams',
        Feature            = 'apps',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = ('T1195', 'T1528'),
        Control            = ('cisa-scuba:MS.TEAMS.5.3', 'nist-800-53-r5:CM-11'),
        Service            = ('Graph', 'Teams'),
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test assesses every custom app category setting.')]
    [OutputType([bool])]
    param()

    return Test-MtCisaTeamsAppControl -SettingName 'PrivateApp' -AppType 'Custom'
}
