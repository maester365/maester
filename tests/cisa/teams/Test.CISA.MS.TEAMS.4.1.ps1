function Test-MtCisaTeamsChannelEmailDisabled {
    <#
    .SYNOPSIS
    Checks that Teams channel email integration is disabled.

    .DESCRIPTION
    Reuses the CIS test because both suites assess the same Global client configuration setting and pass condition.
    The setting may not be available in every Microsoft 365 environment.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.TEAMS.4.1',
        Title              = 'Microsoft Teams email integration SHALL be disabled.',
        Product            = 'teams',
        Feature            = 'messaging',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'High',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = ('T1204.001', 'T1204.002'),
        Control            = ('cisa-scuba:MS.TEAMS.4.1', 'nist-800-53-r5:SI-8', 'nist-800-53-r5:SC-7(10)(a)', 'nist-800-53-r5:AC-4'),
        Service            = 'Teams',
        Author             = 'Copilot'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisTeamsEmailToChannelDisabled
}
