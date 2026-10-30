External sharing of Fabric semantic models is disabled or limited to one or more security groups.

This setting governs the in-place sharing of semantic models with users in another tenant. If misused, it can provide a path for data to be shared outside the organization. It is separate from OneLake external data sharing.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Export and Sharing settings**.
4. Set **Allow specific users to turn on external data sharing** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%