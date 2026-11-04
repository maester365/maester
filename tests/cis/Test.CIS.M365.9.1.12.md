Service-principal access to create Fabric workspaces, connections, and deployment pipelines is disabled or limited to one or more security groups.

These APIs are not governed by Fabric's item permission model. Scope the setting to a group containing only applications that require access; this check confirms a group is configured but does not inspect its membership.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Developer settings**.
4. Set **Service principals can create workspaces, connections, and deployment pipelines** to **Disabled**, or choose **Enabled** with **Specific security groups** selected and defined for the applications that need this access. If the organization doesn't actively use this feature, keep it **Disabled**.
5. Select **Apply**.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#service-principals-can-create-workspaces-connections-and-deployment-pipelines)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%