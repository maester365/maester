Guest browsing of Fabric content is disabled or limited to one or more security groups.

Scoping this setting limits the Fabric content that an external identity can discover through browsing. It does not revoke workspace roles or direct item permissions already granted to guests.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Export and Sharing settings**.
4. Set **Guest users can browse and access Fabric content** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**. Review existing guest workspace and item permissions separately.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%