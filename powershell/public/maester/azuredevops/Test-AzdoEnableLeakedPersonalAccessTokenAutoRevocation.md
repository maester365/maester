Automatic revocation of leaked Personal Access Tokens **should be** enabled.

Rationale: When Personal Access Tokens are leaked and detected, they should be automatically revoked to prevent unauthorized access to Azure DevOps.

#### Remediation action:
Enable the policy to automatically revoke leaked tokens.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Microsoft Entra under General.
4. Switch the Automatically revoke leaked personal access tokens button to ON.

**Results:**
When enabled, Azure DevOps will automatically revoke any Personal Access Tokens that are detected as leaked or exposed.


#### Related links
* [Learn - Automatic revocation of leaked tokens](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#automatic-revocation-of-leaked-tokens)
