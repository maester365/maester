function Test-MtCisFabricGuestAccessRestricted {
    <#
    .SYNOPSIS
    Checks that guest access to Fabric is disabled or limited to one or more security groups.

    .DESCRIPTION
    Restricting the tenant setting narrows which guest cloud accounts can enter Fabric, reducing the reach of a compromised external account. Item permissions continue to control access to individual content.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.1',
        Title              = 'Restrict guest access to Fabric',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = ('cis-m365:9.1.1', 'nist-800-53-r5:AC-3'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'AllowGuestUserToAccessSharedContent' -SettingTitle 'Guest users can access Microsoft Fabric' -Rule DisabledOrGroups
}
