Guest invitations made through Fabric are disabled or limited to one or more security groups.

Restricting this invitation path reduces the chance that an unapproved user creates external access through content sharing. Other Microsoft Entra invitation controls remain separate.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Export and Sharing settings**.
4. Set **Users can invite guest users to collaborate through item sharing and permissions** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%