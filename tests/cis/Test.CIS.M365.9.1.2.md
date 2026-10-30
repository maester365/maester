Guest invitations made through Fabric are disabled or limited to one or more security groups.

Restricting this invitation path reduces the chance that an unapproved user creates external access through content sharing. Other Microsoft Entra invitation controls remain separate.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Export and sharing settings**, find **Users can invite guest users to collaborate through item sharing and permissions**.
4. Choose **Disabled**, or choose **Enabled** and scope the setting to **Specific security groups** with at least one group selected.
5. Select **Apply**.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%