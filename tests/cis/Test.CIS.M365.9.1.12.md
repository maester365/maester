Service-principal access to create Fabric workspaces, connections, and deployment pipelines is disabled or limited to one or more security groups.

These APIs are not governed by Fabric's item permission model. Scope the setting to a group containing only applications that require access; this check confirms a group is configured but does not inspect its membership.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Developer settings**, find **Service principals can create workspaces, connections, and deployment pipelines**.
4. Choose **Disabled**, or choose **Enabled** and scope the setting to **Specific security groups** containing the applications that need this access.
5. Select **Apply**.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#service-principals-can-create-workspaces-connections-and-deployment-pipelines)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%