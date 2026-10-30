function Test-MtCisFabricScriptVisualsDisabled {
    <#
    .SYNOPSIS
    Checks that R and Python visuals are disabled for the Fabric tenant.

    .DESCRIPTION
    These visuals run user-authored scripts while rendering reports. Disabling them reduces the tenant's exposure to script-based code execution through report content.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.5',
        Title              = 'Disable R and Python visuals in Fabric',
        Product            = 'fabric',
        Feature            = 'tenant-settings',
        Area               = 'infrastructure',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1059',
        Control            = ('cis-m365:9.1.5', 'nist-800-53-r5:CM-7'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'RScriptVisual' -SettingTitle 'Interact with and share R and Python visuals' -Rule Disabled
}
