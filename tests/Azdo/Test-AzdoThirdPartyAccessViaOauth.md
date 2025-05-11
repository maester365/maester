Third-party application access via OAuth should be disabled.

Rationale: Third-party application access should not be used for Azure DevOps.

#### Remediation action:
Disable the policy to stops these requests and notifications.
1. Sign in to your organization
2. Choose Organization settings.
3. Select Policies, locate the Request Access policy and toggle it to off.
4. Provide the URL to your internal process for gaining access. Users see this URL in the error report when they try to access the organization or a project within the organization that they don't have permission to access.

**Results:**
When you deny access to an authentication method, no application can access your organization through that method. Any application that previously had access encounter authentication errors and lose access.

#### Related links

* [Learn - Change application connection & security policies for your organization](https://aka.ms/vstspolicyoauth)
* [Learn - Use Azure DevOps OAuth 2.0 to create a web app](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/azure-devops-oauth?view=azure-devops)
