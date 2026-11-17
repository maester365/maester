Checks that at least one Power Platform data loss prevention (DLP) policy applies to the default environment. A policy applies when it covers all environments, names the default environment, or excludes only other environments.

Every user can build apps and flows in the default environment. Without a DLP policy, those apps can connect business data to unapproved external services.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Security**, then **Data and privacy**, then **Data policy**.
3. Select **New policy** and name it.
4. Classify connectors as **Business**, **Non-business** or **Blocked** to restrict the data they can share.
5. On the scope step, include the default environment (or all environments), then create the policy.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.2.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform2)
- [Data policies](https://learn.microsoft.com/power-platform/admin/wp-data-loss-prevention)

<!--- Results --->
%TestResult%
