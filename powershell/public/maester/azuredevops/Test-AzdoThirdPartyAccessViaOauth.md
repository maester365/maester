Third-party application access via OAuth should be disabled.

Rationale: Third-party application access should not be used for Azure DevOps.

#### Remediation action:
Disable the policy to stop these requests and notifications.
1. Sign in to your organization.
2. Choose Organization settings.
3. Select Policies, locate the Third-party application access via Oauth policy and toggle it to off.

**Results:**
To allow seamless access to your organization without repeatedly prompting for user credentials, applications can use authentication methods, like OAuth, SSH, and personal access token (PATs). By default, all existing organizations allow access for all authentication methods.

Third-party application access via OAuth: Enable Azure DevOps OAuth apps to access resources in your organization through OAuth. This policy is defaulted to off for all new organizations. If you want access to Azure DevOps OAuth apps, enable this policy to ensure these apps can access resources in your organization. This policy doesn't affect Microsoft Entra ID OAuth app access.

When you deny access to an authentication method, no application can access your organization through that method. Any application that previously had access will encounter authentication errors and lose access.

#### Related links

* [Learn - Change application connection & security policies for your organization](https://aka.ms/vstspolicyoauth)
* [Learn - Use Azure DevOps OAuth 2.0 to create a web app](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/azure-devops-oauth?view=azure-devops)
