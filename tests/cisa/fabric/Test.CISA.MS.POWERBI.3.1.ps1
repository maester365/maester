function Test-MtCisaPowerBiGuestInvitationsRestricted {
    <#
    .SYNOPSIS
    Checks that Power BI guest invitations are disabled or restricted to security groups.

    .DESCRIPTION
    Runs CIS.M365.9.1.2, whose tenant-setting scope and pass condition match ScubaGear MS.POWERBI.3.1v1.
    This limits creation of external accounts through sharing workflows, not existing guest access.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.3.1',
        Title              = 'Restrict Power BI external invitations',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1136.003',
        Control            = 'cisa-scuba:MS.POWERBI.3.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricGuestInvitationsRestricted
}
