Guest access to Microsoft Fabric is disabled or limited to one or more security groups.

Limiting which guest accounts can enter Fabric reduces exposure from external identities. Item and workspace permissions still determine which content a guest can access.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Export and Sharing settings**.
4. Set **Guest users can access Microsoft Fabric** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**.

#### Related links

* [Export and sharing tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%