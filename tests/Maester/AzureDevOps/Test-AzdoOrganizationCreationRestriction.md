Restrict creation of new Azure DevOps organizations **should be** enabled.

#### Prerequisites

- You must have the Azure DevOps Administrator role in your Microsoft Entra tenant.

#### Rationale

Limiting who can create organizations helps maintain governance, control, and compliance across an enterprise Azure DevOps environment.

#### Remediation action

Enable the tenant policy to restrict organization creation.
1. Sign in to your organization (https://dev.azure.com/{Your_Organization}).
2. Select Organization settings (gear icon).
3. Select Microsoft Entra ID, and move the toggle to On to restrict organization creation.

#### Allowlist and exceptions

- After enabling the policy, add Microsoft Entra users or groups to the allowlist to permit them to create organizations.
- Use groups for allowlists to avoid identity residency concerns.

**Results:**

When enabled, only users on the allowlist (or Azure DevOps Administrators as permitted) can create new organizations.


#### Related links
* [Learn - Restrict organization creation](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/azure-ad-tenant-policy-restrict-org-creation?view=azure-devops#turn-on-the-policy)
