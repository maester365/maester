Publish to web is disabled, or scoped to one or more security groups with new embed-code creation disabled.

The check verifies that the setting has at least one security group and that new embed-code creation is disabled. It does not inventory or revoke existing codes.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Export and Sharing settings**.
4. Set **Publish to web** to **Disabled**, or choose **Enabled**, set **Choose how embed codes work** to **Only allow existing codes**, and select and define **Specific security groups**. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**. Review existing embed codes separately and remove any that expose sensitive reports.

#### Related links

* [Publish to web settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing#publish-to-web)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%