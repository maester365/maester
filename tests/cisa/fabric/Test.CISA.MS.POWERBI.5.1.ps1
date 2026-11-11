function Test-MtCisaPowerBiResourceKeyAuthenticationBlocked {
    <#
    .SYNOPSIS
    Checks that resource-key authentication is blocked for streaming and push datasets.

    .DESCRIPTION
    Runs CIS.M365.9.1.9, whose tenant-setting scope and pass condition match ScubaGear MS.POWERBI.5.1v1.
    Blocking shared resource keys requires clients to use identity-based authentication.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.5.1',
        Title              = 'Block Power BI resource-key authentication',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Control            = 'cisa-scuba:MS.POWERBI.5.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricResourceKeyAuthenticationBlocked
}
