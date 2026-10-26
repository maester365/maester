function Test-MtCisFabricServicePrincipalProfilesRestricted {
    <#
    .SYNOPSIS
    Checks that service-principal profiles are disabled or limited to one or more security groups.

    .DESCRIPTION
    Service-principal profiles support multitenant applications. A compromised service principal with profile access could cross customer data boundaries; restricting this setting limits which application identities can use that capability.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.11',
        Title              = 'Restrict service principal profiles in Fabric',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Low',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = ('cis-m365:9.1.11', 'nist-800-53-r5:AC-3'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'AllowServicePrincipalsCreateAndUseProfiles' -SettingTitle 'Allow service principals to create and use profiles' -Rule DisabledOrGroups
}
