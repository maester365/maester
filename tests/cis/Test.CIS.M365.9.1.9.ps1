function Test-MtCisFabricResourceKeyAuthenticationBlocked {
    <#
    .SYNOPSIS
    Checks that resource-key authentication is blocked for Fabric streaming and push datasets.

    .DESCRIPTION
    Blocking resource keys removes a shared-key authentication path for these dataset APIs and requires clients to use an identity-based method.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.9',
        Title              = 'Block resource-key authentication for Fabric datasets',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'authentication',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Control            = ('cis-m365:9.1.9', 'nist-800-53-r5:IA-5'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'BlockResourceKeyAuthentication' -SettingTitle 'Block ResourceKey Authentication' -Rule Enabled
}