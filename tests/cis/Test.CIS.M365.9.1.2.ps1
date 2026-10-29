function Test-MtCisFabricGuestInvitationsRestricted {
    <#
    .SYNOPSIS
    Checks that Fabric guest invitations are disabled or limited to one or more security groups.

    .DESCRIPTION
    Scoping who can invite guests reduces uncontrolled creation of external identities through Fabric sharing workflows.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.2',
        Title              = 'Restrict external guest invitations through Fabric',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1136.003',
        Control            = ('cis-m365:9.1.2', 'nist-800-53-r5:AC-2'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'ExternalSharingV2' -SettingTitle 'Users can invite guest users to collaborate through item sharing and permissions' -Rule DisabledOrGroups
}
