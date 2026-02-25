Restriction of Personal Access Token lifespan **should be** enabled.

Rationale: Restricting PAT lifespan by setting an expiration date reduces the risk of unauthorized access from compromised or forgotten tokens.

#### Remediation action:
Enable the policy to restrict PAT lifespan.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Microsoft Entra under General.
4. Switch the Restrict global personal access token creation button to ON.
5. Configure the Restrict personal access token lifespan.

**Results:**
When enabled, newly created Personal Access Tokens must have an expiration date. Tokens will automatically expire after the specified period, requiring users to create new tokens.


#### Related links
* [Learn - Restrict personal access token lifespan](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-personal-access-token-lifespan)
