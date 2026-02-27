Automatic revocation of leaked Personal Access Tokens **should be** enabled.

#### Prerequisites

- Your organization must be linked to a Microsoft Entra tenant.
- You must be an Azure DevOps Administrator to configure tenant policies.

#### Rationale

Automatically revoking PATs detected as leaked minimizes the window of opportunity for unauthorized access. Disabling this policy leaves exposed tokens active even if they appear in public repositories.

#### Remediation action

Enable the tenant policy to revoke leaked tokens.
1. Sign in to your organization (https://dev.azure.com/{yourorganization}).
2. Select Organization settings (gear icon).
3. Select Microsoft Entra, locate the "Automatically revoke leaked personal access tokens" policy.
4. Move the toggle to On.

**Results:**

When enabled, Azure DevOps will automatically revoke any PATs detected as leaked or exposed. If the policy is later disabled, tokens checked into public GitHub repositories remain active.


#### Related links
* [Learn - Automatic revocation of leaked tokens](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens)
