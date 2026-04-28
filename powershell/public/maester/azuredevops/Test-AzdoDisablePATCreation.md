Personal Access Token creation **should be** restricted at the organization level.

Rationale: Restricting PAT creation reduces the risk of long-lived credentials being used to access your Azure DevOps organization. Existing personal access tokens remain valid until expiration when the policy is enabled.

#### Remediation action:
Enable the policy to restrict Personal Access Token creation.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Policies, locate the "Restrict personal access token (PAT) creation" policy and toggle it to on.

**Results:**
With the policy enabled, users cannot create new Personal Access Tokens unless explicitly allowed through the allow list.

#### Related links

* [Learn - Manage PATs with policies for administrators](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops)
