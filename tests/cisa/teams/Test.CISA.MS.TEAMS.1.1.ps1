function Test-MtCisaTeamsExternalParticipantControl {
    <#
    .SYNOPSIS
    Checks that external meeting participants cannot request control of shared content.

    .DESCRIPTION
    Checks every Teams meeting policy because the baseline applies to the Global policy and custom policies.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.1',
        Title              = 'External meeting participants SHOULD NOT be enabled to request control of shared desktops or windows.',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('cisa-scuba:MS.TEAMS.1.1', 'nist-800-53-r5:AC-17a'),
        Service            = 'Teams',
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaTeamsMeetingPolicyBoolean `
        -SettingName 'AllowExternalParticipantGiveRequestControl' `
        -ExpectedValue $false `
        -PolicyDescription 'External participants requesting control of shared content'
}
