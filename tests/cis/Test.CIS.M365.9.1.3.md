Guest browsing of Fabric content is disabled or limited to one or more security groups.

Scoping this setting limits the Fabric content that an external identity can discover through browsing. It does not revoke workspace roles or direct item permissions already granted to guests.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Export and sharing settings**, find **Guest users can browse and access Fabric content**.
4. Choose **Disabled**, or choose **Enabled** and scope the setting to **Specific security groups** with at least one group selected.
5. Select **Apply**. Review existing guest workspace and item permissions separately.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%