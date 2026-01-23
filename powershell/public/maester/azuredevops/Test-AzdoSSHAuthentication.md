Connecting to Azure DevOps using SSH should be disabled.

Rationale: Oauth is the prefered and most secure authentication method.

#### Remediation action:
Disable the policy to stops these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Policies under the Security section.
4. Locate the "SSH authentication" policy and toggle it to off.

**Results:**
Users can no longer user SSH to connect to Azure DevOps.

#### Related links

* [Learn - Use SSH key authentication](https://aka.ms/vstspolicyssh)
* [Learn - Authentication with Azure Repos](https://learn.microsoft.com/en-us/azure/devops/repos/git/auth-overview?view=azure-devops&source=recommendations&tabs=Windows)
