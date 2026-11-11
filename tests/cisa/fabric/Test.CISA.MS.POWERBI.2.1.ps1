function Test-MtCisaPowerBiGuestAccessRestricted {
    <#
    .SYNOPSIS
    Checks that Power BI guest access is disabled or restricted to security groups.

    .DESCRIPTION
    Runs CIS.M365.9.1.1, whose tenant-setting scope and pass condition match ScubaGear MS.POWERBI.2.1v1.
    Restricting access reduces exposure from compromised guest cloud accounts.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.2.1',
        Title              = 'Restrict Power BI guest access',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = 'cisa-scuba:MS.POWERBI.2.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricGuestAccessRestricted
}
