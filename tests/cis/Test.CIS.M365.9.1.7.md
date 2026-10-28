Organization-wide Fabric sharing links are disabled or limited to one or more security groups.

An organization-wide link can grant access to tenant users who were not individually granted access. Restricting who can create these links reduces accidental internal disclosure; it does not govern external guests.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Export and sharing settings**, find **Allow shareable links to grant access to everyone in your organization**.
4. Choose **Disabled**, or choose **Enabled** and scope link creation to **Specific security groups** with at least one group selected.
5. Select **Apply**.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%