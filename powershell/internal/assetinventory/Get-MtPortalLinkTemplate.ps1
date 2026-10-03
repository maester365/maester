function Get-MtPortalLinkTemplate {
    <#
    .SYNOPSIS
    Returns the shared portal deep-link templates and odata type mappings for known Graph object types.

    .DESCRIPTION
    Single source of truth for the GraphObjectType → admin portal deep-link mapping used by
    Get-GraphObjectMarkdown (markdown rendering) and Add-MtTestResultDetail (structured
    RelatedObjects records for the asset inventory).

    Link templates use {0} as the placeholder for the object id. Types without {0}
    are tenant-level settings surfaces that have no per-object deep link.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        # GraphObjectType → portal deep-link template ({0} = object id)
        LinkTemplates    = @{
            AuthenticationMethod = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods"
            AuthorizationPolicy  = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings"
            ConditionalAccess    = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/{0}"
            ConsentPolicy        = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings"
            Devices              = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_Devices/DeviceDetailsMenuBlade/~/Properties/objectId/{0}"
            Domains              = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomDomainNames"
            Groups               = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/{0}"
            IdentityProtection   = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/IdentityProtectionMenuBlade/~/UsersAtRiskAlerts/fromNav/Identity"
            Users                = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/{0}"
            UserRole             = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/AdministrativeRole/userId/{0}"
        }
        # @odata.type → GraphObjectType (auto-detection when no explicit type is passed)
        OdataTypeMapping = @{
            '#microsoft.graph.user'   = 'Users'
            '#microsoft.graph.group'  = 'Groups'
            '#microsoft.graph.device' = 'Devices'
        }
        # GraphObjectType → whether the deep link addresses a single object instance
        # (types not listed here resolve to a tenant-level settings surface)
        InstanceTypes    = @('ConditionalAccess', 'Devices', 'Groups', 'Users', 'UserRole')
    }
}
