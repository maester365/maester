## Description

This test identifies Microsoft Entra ID Governance access packages that contain assignment policies which are disabled, misconfigured, or orphaned. Inactive or misconfigured policies prevent users from successfully requesting access and can break automated provisioning workflows.

The test validates:
- Policies are in "published" state and active
- Requestor scope type is properly configured (not "NoSubjects" or null)
- Required approval settings are complete with designated approvers
- Policies have not expired
- Required questions have proper text configured

## Remediation action

**For Unpublished Policies:**
1. Navigate to [Entra Admin Center → Identity Governance → Access Packages](https://entra.microsoft.com/#view/Microsoft_AAD_ELM/Dashboard.ReactView)
2. Select the affected access package → **Policies** tab
3. Review the policy state:
   - If should be active: Publish it
   - If no longer needed: Delete it

**For Missing Requestor Settings:**
1. Edit the problematic policy → **Requestor** settings
2. Configure **Who can request** with appropriate scope (All users, Specific users, etc.)
3. Ensure scope type is valid and not deprecated

**For Missing/Invalid Approval Settings:**
1. Edit the policy → **Approval** settings
2. If approval required:
   - Add at least one approval stage
   - Configure primary approvers for each stage
   - Ensure approver groups exist
3. If not required: Disable approval requirement

**For Expired Policies:**
1. Review if expiration was intentional
2. If still needed: Edit policy and update expiration date or remove expiration
3. If no longer needed: Delete the policy

**For Question Configuration Issues:**
1. Edit the policy → **Requestor information** section
2. Ensure all required questions have proper text configured
3. Validate question type and requirements

## Related links

- [Microsoft Entra ID Governance Documentation](https://learn.microsoft.com/entra/id-governance/)
- [Access Package Assignment Policies](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-request-policy)
- [Configure Access Package Request Settings](https://learn.microsoft.com/entra/id-governance/entitlement-management-access-package-approval-policy)
- [Microsoft Graph API - Assignment Policies](https://learn.microsoft.com/graph/api/resources/accesspackageassignmentpolicy)
