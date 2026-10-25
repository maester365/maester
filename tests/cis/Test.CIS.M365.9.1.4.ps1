function Test-MtCisFabricPublishToWebRestricted {
    <#
    .SYNOPSIS
    Checks that Publish to web is disabled or scoped to one or more security groups with new code creation disabled.

    .DESCRIPTION
    Public embed codes do not require sign-in. Disabling new code creation and limiting eligible users reduces the chance of exposing report data to anyone on the internet.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.4',
        Title              = 'Restrict public publishing of Fabric reports',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'T1567',
        Control            = ('cis-m365:9.1.4', 'nist-800-53-r5:AC-22'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'PublishToWeb' -SettingTitle 'Publish to web' -Rule PublishToWeb
}