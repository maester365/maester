Service-principal profile creation and use are disabled or limited to one or more security groups.

Profiles are used by multitenant applications to isolate customer contexts. Restricting this capability helps contain misuse of an application identity and protects those boundaries.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Developer settings**.
4. Set **Allow service principals to create and use profiles** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined for the applications that need this access. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#allow-service-principals-to-create-and-use-profiles)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%