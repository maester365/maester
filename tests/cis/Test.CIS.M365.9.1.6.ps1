function Test-MtCisFabricSensitivityLabelsEnabled {
    <#
    .SYNOPSIS
    Checks that users can apply sensitivity labels to Fabric content.

    .DESCRIPTION
    Without this setting, users cannot apply Microsoft Purview sensitivity labels to supported Fabric content and exports. Enabling it makes labels available; this check does not verify that labels are published or applied.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.6',
        Title              = 'Enable sensitivity labels for Fabric content',
        Product            = 'fabric',
        Feature            = 'information-protection',
        Area               = 'data-protection',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Control            = ('cis-m365:9.1.6', 'nist-800-53-r5:AC-16'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'EimInformationProtectionEdit' -SettingTitle 'Allow users to apply sensitivity labels for content' -Rule Enabled
}