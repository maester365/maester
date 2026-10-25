function Test-MtCisFabricExternalSharingRestricted {
    <#
    .SYNOPSIS
    Checks that external semantic-model sharing is disabled or limited to one or more security groups.

    .DESCRIPTION
    Limiting who can initiate in-place sharing reduces the number of users able to expose semantic models to another organization's tenant.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.8',
        Title              = 'Restrict external sharing of semantic models',
        Product            = 'fabric',
        Feature            = 'export-and-sharing',
        Area               = 'external-access',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1567',
        Control            = ('cis-m365:9.1.8', 'nist-800-53-r5:AC-21'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'EnableDatasetInPlaceSharing' -SettingTitle 'Allow specific users to turn on external data sharing' -Rule DisabledOrGroups
}