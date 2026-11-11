function Test-MtCisaPowerBiScriptVisualsDisabled {
    <#
    .SYNOPSIS
    Checks that Power BI R and Python visuals are disabled.

    .DESCRIPTION
    Runs CIS.M365.9.1.5, whose tenant-setting scope and pass condition match ScubaGear MS.POWERBI.6.1v1.
    Disabling user-authored script visuals reduces script-based execution through report content.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.6.1',
        Title              = 'Disable Power BI R and Python interactions',
        Product            = 'fabric',
        Feature            = 'tenant-settings',
        Area               = 'infrastructure',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1059',
        Control            = 'cisa-scuba:MS.POWERBI.6.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricScriptVisualsDisabled
}
