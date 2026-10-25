function Test-MtCisFabricPublicApiAccessRestricted {
    <#
    .SYNOPSIS
    Checks that service-principal access to Fabric public APIs is disabled or limited to one or more security groups.

    .DESCRIPTION
    A compromised service-principal cloud account can use these APIs within its Fabric permissions. Scoping the setting limits which valid application identities can use this path.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.10',
        Title              = 'Restrict service principal access to Fabric public APIs',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = ('cis-m365:9.1.10', 'nist-800-53-r5:AC-3'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'ServicePrincipalAccessPermissionAPIs' -SettingTitle 'Service principals can call Fabric public APIs' -Rule DisabledOrGroups
}