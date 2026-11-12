function Test-MtCisaPowerBiSensitivityLabel {
    <#
    .SYNOPSIS
    Checks that users can apply sensitivity labels to Power BI content.

    .DESCRIPTION
    Reuses CIS.M365.9.1.6 for ScubaGear's automated EimInformationProtectionEdit.enabled equals true audit.
    Label publication and use on sensitive content are covered by the remediation guidance, not this tenant-setting audit.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.7.1',
        Title              = 'Enable and employ Power BI sensitivity labels',
        Product            = 'fabric',
        Feature            = 'information-protection',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Control            = 'cisa-scuba:MS.POWERBI.7.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return [bool](Test-MtCisFabricSensitivityLabelsEnabled)
}
