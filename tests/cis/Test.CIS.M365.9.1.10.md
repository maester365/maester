Service-principal access to Fabric public APIs is disabled or limited to one or more security groups.

This setting governs APIs protected by the Fabric permission model. Restricting the allowed service principals reduces the impact of a compromised application identity.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Developer settings**.
4. Set **Service principals can call Fabric public APIs** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined for the applications that need this access. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#service-principals-can-call-fabric-public-apis)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%