function Test-MtCisaPowerBiServicePrincipalProfilesRestricted {
    <#
    .SYNOPSIS
    Checks that service-principal profiles are disabled or restricted to security groups.

    .DESCRIPTION
    Runs CIS.M365.9.1.11, whose tenant-setting scope and pass condition match ScubaGear MS.POWERBI.4.2v1.
    This limits profile access by compromised cloud application identities.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.4.2',
        Title              = 'Restrict Power BI service-principal profiles',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = 'cisa-scuba:MS.POWERBI.4.2',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricServicePrincipalProfilesRestricted
}
