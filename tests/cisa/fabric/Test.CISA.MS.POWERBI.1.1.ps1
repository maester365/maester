function Test-MtCisaPowerBiPublishToWebDisabled {
    <#
    .SYNOPSIS
    Checks that Power BI Publish to web is disabled.

    .DESCRIPTION
    Applies ScubaGear's PublishToWeb.enabled equals false audit. Public reports need no authentication.
    Unlike CIS.M365.9.1.4, restricted creation of embed codes is not an automated pass.
    #>
    [MaesterTest(
        Id                 = 'CISA.MS.POWERBI.1.1',
        Title              = 'Disable Power BI publishing to the public web',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1530',
        Control            = 'cisa-scuba:MS.POWERBI.1.1',
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule Disabled
}
