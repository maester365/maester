function Test-MtCisFabricGuestBrowsingRestricted {
    <#
    .SYNOPSIS
    Checks that guest browsing of Fabric content is disabled or limited to one or more security groups.

    .DESCRIPTION
    Guest browsing can help an external identity discover Fabric content. Restricting it reduces this data-collection surface for an attacker using a compromised guest account; it does not remove workspace roles or direct item permissions already assigned to guests.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.3',
        Title              = 'Restrict guest browsing of Fabric content',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1213',
        Control            = ('cis-m365:9.1.3', 'nist-800-53-r5:AC-3'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'ElevatedGuestsTenant' -SettingTitle 'Guest users can browse and access Fabric content' -Rule DisabledOrGroups
}