function Test-MtCisaPowerBiSensitivityLabel {
    <#
    .SYNOPSIS
    Checks label enablement and requests review of sensitive-data labeling.

    .DESCRIPTION
    Reuses CIS.M365.9.1.6 for ScubaGear's EimInformationProtectionEdit.enabled equals true audit.
    The tenant setting does not establish that sensitive content is labeled according to enterprise policy.
    An enabled setting therefore requires human investigation, rather than reporting full compliance.
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

    $enabled = Test-MtCisFabricSensitivityLabelsEnabled
    if (-not $enabled) {
        return $false
    }

    Add-MtTestResultDetail -Investigate -Result 'Sensitivity labels are enabled. Manually verify that labels are defined and published to relevant users and groups, and employed on sensitive Power BI content according to enterprise data protection policy. Tenant settings alone cannot establish this. Review the remediation steps and retain assessment evidence.'
    return $false
}
