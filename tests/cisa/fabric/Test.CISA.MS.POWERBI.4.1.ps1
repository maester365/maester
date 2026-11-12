function Test-MtCisaPowerBiServicePrincipalApisRestricted {
    <#
    .SYNOPSIS
    Checks that service-principal access to Fabric public APIs is disabled or group-restricted.

    .DESCRIPTION
    Runs CIS.M365.9.1.10, whose tenant-setting scope and pass condition match ScubaGear MS.POWERBI.4.1v1.
    Restricting access limits which compromised application identities can call these APIs.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.4.1',
        Title              = 'Restrict Power BI service-principal API access',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = 'cisa-scuba:MS.POWERBI.4.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricPublicApiAccessRestricted
}
