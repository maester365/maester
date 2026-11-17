Lists the Power Platform tenant isolation exceptions so they can be reviewed. ScubaGear audits this requirement manually, so the result is always **Investigate**.

When tenant isolation is on, an allowlist of trusted tenants limits inbound and outbound connections to those the organization has approved. Review that every listed tenant is still needed and that its direction is correct.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Security**, then **Identity and access**, then **Tenant isolation**.
3. Select **New tenant rule**, enter the tenant ID or domain, and choose **Inbound**, **Outbound** or both.
4. Remove rules for tenants that are no longer trusted, then select **Save**.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.3.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform3)
- [Cross-tenant inbound and outbound restrictions](https://learn.microsoft.com/power-platform/admin/cross-tenant-restrictions)

<!--- Results --->
%TestResult%
