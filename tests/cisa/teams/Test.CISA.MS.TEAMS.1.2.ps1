function Test-MtCisaTeamsAnonymousMeetingStart {
    <#
    .SYNOPSIS
    Checks that anonymous users cannot start Teams meetings.

    .DESCRIPTION
    Checks the Global meeting policy and every custom meeting policy.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.2',
        Title              = 'Anonymous users SHALL NOT be enabled to start Microsoft Teams meetings.',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.001',
        Control            = 'cisa-scuba:MS.TEAMS.1.2',
        Service            = 'Teams',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaTeamsMeetingPolicyBoolean `
        -SettingName 'AllowAnonymousUsersToStartMeeting' `
        -ExpectedValue $false `
        -PolicyDescription 'Anonymous users starting Teams meetings'
}
