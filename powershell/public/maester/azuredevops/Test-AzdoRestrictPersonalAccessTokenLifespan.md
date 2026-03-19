Restrict setting a maximum Personal Access Token (PAT) lifespan **should be** enabled.

#### Prerequisites

- Your organization must be linked to a Microsoft Entra tenant.
- You must be an Azure DevOps Administrator to configure tenant policies.

#### Rationale

Restricting PAT lifespan by enforcing a maximum expiration reduces the risk of long-lived credentials being reused after compromise, helps meet compliance requirements, and encourages regular credential rotation.

#### Remediation action

Enable the tenant policy to enforce a maximum PAT lifespan.
1. Sign in to your organization (https://dev.azure.com/{yourorganization}).
2. Select Organization settings (gear icon).
3. Select Microsoft Entra, find the "Enforce maximum personal access token lifespan" policy.
4. Move the toggle to On.
5. Enter the maximum number of days and select Save.

#### Allowlist and exceptions

- Each tenant policy has its own allowlist; add Microsoft Entra users or groups to exempt them from the restriction.
- Use groups for allowlists; adding named users can create identity residency concerns.

**Existing PATs:**

Existing PATs remain valid until their configured expiration date and are not retroactively shortened by this setting.

**Results:**

When enabled, newly created or renewed PATs will have a maximum lifespan (in days) and will automatically expire after that period.


#### Related links
* [Learn - Restrict personal access token lifespan](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-personal-access-token-lifespan)
