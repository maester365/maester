function Test-MtCisaTeamsDialInLobby {
    <#
    .SYNOPSIS
    Checks that dial-in users cannot bypass the meeting lobby.

    .DESCRIPTION
    Checks every Teams meeting policy, including the Global and custom policies.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.5',
        Title              = 'Dial-in users SHOULD NOT be able to bypass the lobby.',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('cisa-scuba:MS.TEAMS.1.5', 'nist-800-53-r5:SC-15a'),
        Service            = 'Teams',
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaTeamsMeetingPolicyBoolean `
        -SettingName 'AllowPSTNUsersToBypassLobby' `
        -ExpectedValue $false `
        -PolicyDescription 'Dial-in users bypassing the meeting lobby'
}
