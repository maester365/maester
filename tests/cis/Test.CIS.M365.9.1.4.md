Publish to web is disabled, or scoped to one or more security groups with new embed-code creation disabled.

The check verifies that the setting has at least one security group and that new embed-code creation is disabled. It does not inventory or revoke existing codes.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Export and sharing settings**, find **Publish to web**.
4. Choose **Disabled**, or choose **Enabled**, allow only existing embed codes, and scope the setting to **Specific security groups** with at least one group selected.
5. Select **Apply**. Review existing embed codes separately and remove any that expose sensitive reports.

#### Related links

* [Publish to web settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing#publish-to-web)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%