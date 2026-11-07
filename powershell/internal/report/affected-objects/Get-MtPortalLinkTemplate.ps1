function Get-MtPortalLinkTemplate {
    <#
    .SYNOPSIS
    Returns the shared portal deep-link templates and odata type mappings for known Graph object types.

    .DESCRIPTION
    Single source of truth for the GraphObjectType → admin portal deep-link mapping used by
    Get-GraphObjectMarkdown (markdown rendering) and Add-MtTestResultDetail (structured
    RelatedObjects records for the affected objects).

    Link templates use {0} as the placeholder for the object id. Types without {0}
    are tenant-level settings surfaces that have no per-object deep link. App registrations are
    not listed: their portal blade is addressed by appId, not by object id.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        # GraphObjectType → portal deep-link template ({0} = object id)
        LinkTemplates    = @{
            AccessPackageCatalogs = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_Azure_ELMAdmin/CatalogBlade/catalogId/{0}"
            AccessPackages        = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_Azure_ELMAdmin/EntitlementMenuBlade/~/overview/entitlementId/{0}"
            AuthenticationMethod  = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/AuthenticationMethodsMenuBlade/~/AdminAuthMethods"
            AuthorizationPolicy   = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/UserSettings"
            ConditionalAccess     = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/{0}"
            ConsentPolicy         = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/ConsentPoliciesMenuBlade/~/UserSettings"
            Devices               = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_Devices/DeviceDetailsMenuBlade/~/Properties/objectId/{0}"
            Domains               = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomDomainNames"
            Groups                = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Overview/groupId/{0}"
            IdentityProtection    = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/IdentityProtectionMenuBlade/~/UsersAtRiskAlerts/fromNav/Identity"
            ServicePrincipals     = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/{0}"
            Users                 = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/{0}"
            UserRole              = "$($__MtSession.AdminPortalUrl.Entra)#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/AdministrativeRole/userId/{0}"
        }
        # @odata.type → GraphObjectType (auto-detection when no explicit type is passed)
        OdataTypeMapping = @{
            '#microsoft.graph.accessPackage'        = 'AccessPackages'
            '#microsoft.graph.accessPackageCatalog' = 'AccessPackageCatalogs'
            '#microsoft.graph.device'               = 'Devices'
            '#microsoft.graph.group'                = 'Groups'
            '#microsoft.graph.servicePrincipal'     = 'ServicePrincipals'
            '#microsoft.graph.user'                 = 'Users'
        }
        # GraphObjectType → whether the deep link addresses a single object instance
        # (types not listed here resolve to a tenant-level settings surface)
        InstanceTypes    = @('AccessPackageCatalogs', 'AccessPackages', 'ConditionalAccess', 'Devices', 'Groups', 'ServicePrincipals', 'Users', 'UserRole')
    }
}
