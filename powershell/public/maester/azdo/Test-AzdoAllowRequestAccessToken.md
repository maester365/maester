Request access to Azure DevOps by e-mail notifications to administrators SHOULD BE disabled.

Rationale: Access control to Azure DevOps is to be a controlled process where access is granted and tracked.

#### Remediation action:
Disable the policy to stops these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Policies, locate the Request Access policy and toggle it to off.
4. Provide the URL to your internal process for gaining access. Users see this URL in the error report when they try to access the organization or a project within the organization that they don't have permission to access.

**Results:**
Users already part of the organization: If they lack permission to access a specific project, they get a 404 error. To maintain confidentiality, the 404 error doesn’t reveal whether the project exists and so doesn't provide a link to request access.
Users not part of the organization: If they attempt to access a resource, they get a 401 error, which includes a link to the configured custom URL for requesting access.

#### Related links

* [Azure DevOps Security - Disable your organization's Request Access policy](https://go.microsoft.com/fwlink/?linkid=2113172)
