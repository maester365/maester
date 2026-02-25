Creation of new Azure DevOps organizations **should be** restricted.

Rationale: Restricting organization creation helps maintain governance and control over the Azure DevOps environment by limiting who can create new organizations.

#### Remediation action:
Enable the policy to restrict organization creation.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Microsoft Entra under General.
4. Switch the Restrict organization creation button to ON.

**Results:**
When enabled, only users with the appropriate permissions will be able to create new Azure DevOps organizations.


#### Related links
* [Learn - Restrict organization creation](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/azure-ad-tenant-policy-restrict-org-creation?view=azure-devops#turn-on-the-policy)
