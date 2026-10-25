function Test-MtCisFabricGlobalApiAccessRestricted {
    <#
    .SYNOPSIS
    Checks that service-principal access to create workspaces, connections, and deployment pipelines is disabled or limited to one or more security groups.

    .DESCRIPTION
    These APIs are not protected by the Fabric item permission model. A compromised service-principal cloud account could use them to create Fabric resources. This check verifies that the setting is disabled or has a nonempty security-group scope; it does not inspect the configured groups or their membership.
    #>
    [MaesterTest(
        Id                 = 'CIS.M365.9.1.12',
        Title              = 'Restrict service principal access to Fabric global APIs',
        Product            = 'fabric',
        Feature            = 'developer-settings',
        Area               = 'applications',
        ResourceType       = 'Tenant',
        Severity           = 'Medium',
        UserImpact         = 'Medium',
        ImplementationCost = 'Low',
        Mitre              = 'T1078.004',
        Control            = ('cis-m365:9.1.12', 'nist-800-53-r5:AC-3'),
        Service            = 'Azure',
        Author             = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisFabricTenantSetting -SettingName 'ServicePrincipalAccessGlobalAPIs' -SettingTitle 'Service principals can create workspaces, connections, and deployment pipelines' -Rule DisabledOrGroups
}