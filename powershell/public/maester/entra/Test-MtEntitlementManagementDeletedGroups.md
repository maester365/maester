## Description

This test identifies Microsoft Entra ID Governance access packages and catalogs that contain references to deleted Entra ID groups. Deleted group references can cause access provisioning failures, broken approval workflows, and compliance violations.

The test validates:
- Groups assigned as resources in access packages still exist
- Groups configured as approvers in assignment policies are active
- Groups registered in catalogs have not been deleted

For any deleted groups found, the test attempts to retrieve the group name from the recycle bin (`directory/deletedItems`) to help identify which groups need attention.

## Remediation action

**Option 1: Remove Deleted Group References**
1. Navigate to [Entra Admin Center → Identity Governance → Access Packages](https://entra.microsoft.com/#view/Microsoft_AAD_ELM/Dashboard.ReactView)
2. For each affected access package:
   - Go to **Resources** and remove the deleted group
   - Update assignment policies to remove deleted group approvers
3. For affected catalogs:
   - Select the catalog → **Resources**
   - Remove the deleted group

**Option 2: Restore Deleted Groups**
1. Navigate to [Entra Admin Center → Identity → Groups → Deleted groups](https://entra.microsoft.com/#blade/Microsoft_AAD_IAM/GroupsManagementMenuBlade/DeletedGroups)
2. Select the deleted group(s) and click **Restore group**
3. Re-run the test to confirm resolution

**Option 3: Replace with Active Groups**
1. Create or identify replacement active groups
2. Add new groups to access packages/catalogs
3. Update assignment policies with new approver groups
4. Remove deleted group references

## Related links

- [Microsoft Entra ID Governance Documentation](https://learn.microsoft.com/entra/id-governance/)
- [Access Packages Overview](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-create)
- [Manage Resources in Access Packages](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-resources)
- [Access Package Catalogs](https://learn.microsoft.com/entra/id-governance/entitlement-management-catalog-create)
- [Microsoft Graph API - Entitlement Management](https://learn.microsoft.com/graph/api/resources/entitlementmanagement-overview)
