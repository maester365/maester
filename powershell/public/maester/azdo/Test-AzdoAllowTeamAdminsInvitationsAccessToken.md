Access to Azure DevOps SHOULD BE a controlled process provided by the IAM team.

Rationale: By default, all administrators can invite new users to their Azure DevOps organization. 
Disabling this policy prevents Team and Project Administrators from inviting new users. 
However, Project Collection Administrators (PCAs) can still add new users to the organization regardless of the policy status. 
Additionally, if a user is already a member of the organization, Project and Team Administrators can add that user to specific projects.

#### Remediation action:
Disable the policy to stop these invitations.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Policies, locate the **Allow team and project administrators to invite new users** policy and toggle it to off.
4. Now, only Project Collection Administrators can invite new users to Azure DevOps.

> Project and Team Administrators can directly add users to their projects through the permissions blade. However, if they attempt to add users through the Add Users button located in the Organization settings > Users section, it's not visible to them. Adding a user directly through Project settings > Permissions doesn't result in the user appearing automatically in the Organization settings > Users list. For the user to be reflected in the Users list, they must sign in to the system.

#### Related links

* [Azure DevOps Security - Restrict administrators from inviting new users](https://aka.ms/azure-devops-invitations-policy)
