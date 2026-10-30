function Test-MtCisFabricOrganizationLinksRestricted {
    <#
    .SYNOPSIS
    Checks that organization-wide sharing links are disabled or limited to one or more security groups.

    .DESCRIPTION
    Restricting who can create these links reduces unintended access by other tenant users who do not otherwise have permission to the content.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.7',
        Title              = 'Restrict organization-wide Fabric links',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'access-control',
        ResourceType       = 'Tenant',
        Severity           = 'Low',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'None',
        Control            = ('cis-m365:9.1.7', 'nist-800-53-r5:AC-3'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'ShareLinkToEntireOrg' -SettingTitle 'Allow shareable links to grant access to everyone in your organization' -Rule DisabledOrGroups
}
