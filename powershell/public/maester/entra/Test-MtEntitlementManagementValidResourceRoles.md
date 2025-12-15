## Description

This test identifies Microsoft Entra ID Governance access package catalog resources that reference stale or invalid roles, deleted service principals, or non-existent SharePoint sites. When applications or sites are reconfigured or deleted, catalogs often retain "ghost roles" that cause provisioning failures.

The test validates:
- Service principals referenced by applications are active and accessible
- Application roles assigned in access packages still exist in their service principals
- SharePoint sites have valid URLs and are accessible via Microsoft Graph API
- Resources are properly configured

**Note:** Group validation is handled by MT.1107. Built-in roles are excluded as they are system-managed. "Default Access" roles are skipped as system defaults.

Stale resources detected:
- **Deleted service principals** - Application removed from tenant (404 error)
- **Stale app roles** - Roles removed from service principal but still assigned in packages
- **Invalid SharePoint URLs** - Site URL format incorrect or site deleted/moved
- **Inaccessible sites** - Site exists but cannot be accessed via Graph API

## Remediation action

**For Deleted Service Principals/Applications:**

*Option 1: Remove from Catalog*
1. Navigate to [Entra Admin Center → Identity Governance → Catalogs](https://entra.microsoft.com/#view/Microsoft_AAD_ELM/Dashboard.ReactView)
2. Select the catalog → **Resources** section
3. Select the stale application resource
4. Click **Remove from catalog**
5. Update any access packages that referenced this resource

*Option 2: Restore Application*
1. Check [Entra Admin Center → Enterprise applications → Deleted applications](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/~/AppAppsPreview)
2. Restore the application if within recovery window
3. Verify catalog resource is now valid

**For Stale App Roles:**
1. Identify the app role from test results
2. Find the service principal in Entra portal
3. If role removed intentionally:
   - Edit the access package
   - Remove the stale resource role assignment
   - Add a valid app role if needed
4. If role should exist:
   - Contact application owner to restore role in app manifest
   - Update app registration to add role back

**For SharePoint Sites:**

*Option 1: Remove from Catalog*
1. Navigate to catalog → **Resources**
2. Select the site and click **Remove from catalog**
3. Update access packages

*Option 2: Fix Site URL* (if moved/renamed)
1. Verify correct URL in [SharePoint Admin Center](https://admin.microsoft.com/sharepoint)
2. Remove old site resource from catalog
3. Add site with correct URL as new resource
4. Update access packages

*Option 3: Restore Site*
1. Check [SharePoint Admin Center → Deleted sites](https://admin.microsoft.com/sharepoint?page=recycleBin)
2. Restore site if within 93-day recovery window
3. Verify accessibility

## Related links

- [Microsoft Entra ID Governance Documentation](https://learn.microsoft.com/entra/id-governance/)
- [Manage Catalog Resources](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-resources)
- [Service Principal App Roles](https://learn.microsoft.com/graph/api/resources/approle)
- [SharePoint Site Resource Type](https://learn.microsoft.com/graph/api/resources/site)
- [Microsoft Graph API - Entitlement Management](https://learn.microsoft.com/graph/api/resources/entitlementmanagement-overview)