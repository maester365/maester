Service-principal access to Fabric public APIs is disabled or limited to one or more security groups.

This setting governs APIs protected by the Fabric permission model. Restricting the allowed service principals reduces the impact of a compromised application identity.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Developer settings**, find **Service principals can call Fabric public APIs**.
4. Choose **Disabled**, or choose **Enabled** and scope access to **Specific security groups** containing the applications that need this access.
5. Select **Apply**.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#service-principals-can-call-fabric-public-apis)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%