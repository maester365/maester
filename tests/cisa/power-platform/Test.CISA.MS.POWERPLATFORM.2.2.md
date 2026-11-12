Checks that every non-default Power Platform environment is covered by at least one data loss prevention (DLP) policy, either through a policy that applies to all environments or through policies that cover each environment.

Environments without a DLP policy allow unrestricted connector use, which can move organizational data to unapproved services.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Security**, then **Data and privacy**, then **Data policy**.
3. Create a new policy, or edit an existing one, and classify connectors as **Business**, **Non-business** or **Blocked**.
4. On the scope step, add each uncovered environment listed in the result, or apply the policy to all environments.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.2.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform2)
- [Data policies](https://learn.microsoft.com/power-platform/admin/wp-data-loss-prevention)

<!--- Results --->
%TestResult%
