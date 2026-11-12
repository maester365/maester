Checks that Power Platform tenant isolation is enabled. A tenant that has never configured the policy fails.

With isolation off, connectors can exchange data with any other Microsoft Entra tenant, so a user can send organizational data to an external tenant or accept data from one.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Security**, then **Identity and access**, then **Tenant isolation** (or **Policies** and **Tenant isolation**).
3. Turn on **Restrict cross-tenant connections**.
4. Select **Save**.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform3)
- [Cross-tenant inbound and outbound restrictions](https://learn.microsoft.com/power-platform/admin/cross-tenant-restrictions)

<!--- Results --->
%TestResult%
