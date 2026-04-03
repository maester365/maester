External guest access to Azure DevOps **should be** a controlled process.

Rationale: External guest access can introduce potential security risks if not managed properly.

#### Remediation action:
Disable the "External guest access" policy to prevent external guest access if there's no business need for it.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Policies, locate the External guest access policy and toggle it to off.

#### Related links

* [Azure DevOps Security - Manage external guest access](https://learn.microsoft.com/en-us/azure/devops/organizations/security/security-overview?view=azure-devops#manage-external-guest-access)