function Test-MtCisaTeamsCloudRecording {
    <#
    .SYNOPSIS
    Checks that meeting recording is disabled in the Global policy.

    .DESCRIPTION
    Reuses the CIS check because both suites assess the same Global policy setting and pass condition.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.1.6',
        Title              = 'Meeting recording SHOULD be disabled.',
        Product            = 'teams',
        Feature            = 'meetings',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = 'cisa-scuba:MS.TEAMS.1.6',
        Service            = 'Teams',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisTeamsMeetingRecording
}
