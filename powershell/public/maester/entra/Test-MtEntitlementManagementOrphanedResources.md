## Description

This test identifies Microsoft Entra ID Governance access package catalogs that contain resources (groups, applications, SharePoint sites) that are not used in any access package within that catalog. Orphaned resources indicate incomplete configuration or drift.

The test validates:
- All catalog resources are referenced in at least one access package
- No orphaned or unused resources exist in catalogs
- Resources serve their intended governance purpose

Common scenarios detected:
- Resources added to catalog but package not yet configured
- Access package was deleted but resource remained in catalog
- Resources removed from packages but not from catalog
- Test resources added and never cleaned up

## Remediation action

**Option 1: Add to Access Package** (if resource should be governed)
1. Navigate to [Entra Admin Center → Identity Governance → Catalogs](https://entra.microsoft.com/#view/Microsoft_AAD_ELM/Dashboard.ReactView)
2. Open an existing access package or create a new one
3. Add the resource to the package's resource roles
4. Configure appropriate roles and permissions
5. Update package policies as needed

**Option 2: Remove from Catalog** (if resource no longer needed)
1. Navigate to [Entra Admin Center → Identity Governance → Catalogs](https://entra.microsoft.com/#view/Microsoft_AAD_ELM/Dashboard.ReactView)
2. Select the catalog → **Resources** section
3. Select the unused resource
4. Click **Remove from catalog**
5. Confirm removal

**Bulk Remediation Process:**
1. Review with stakeholders to identify which resources are still needed
2. Create access packages for resources that should be governed
3. Clean up catalog by removing resources no longer needed
4. Document decisions and update procedures

## Related links

- [Microsoft Entra ID Governance Documentation](https://learn.microsoft.com/entra/id-governance/)
- [Access Package Catalogs](https://learn.microsoft.com/entra/id-governance/entitlement-management-catalog-create)
- [Manage Catalog Resources](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-resources)
- [Microsoft Graph API - Entitlement Management](https://learn.microsoft.com/graph/api/resources/entitlementmanagement-overview)