Creation of global PATs **should be** restricted.

Rationale: PATs are the least secure authentication method provided in Azure DevOps. When used, these should be scoped according to the principle of least privilege.

#### Remediation action:
Enable the policy to stop these requests and notifications.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Microsoft Entra under General.
4. Switch the Restrict global personal access token creation button to ON.

**Results:**
If enabled, new personal access tokens (PATs) must be associated with specific Azure DevOps organizations. Creating global tokens (tokens that work for all accessible organizations) will be restricted from all users.


#### Related links
* [Learn - Restrict creation of global PATs (tenant policy)](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/manage-pats-with-policies-for-administrators?view=azure-devops#restrict-creation-of-global-pats-tenant-policy)
