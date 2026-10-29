Service-principal profile creation and use are disabled or limited to one or more security groups.

Profiles are used by multitenant applications to isolate customer contexts. Restricting this capability helps contain misuse of an application identity and protects those boundaries.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Developer settings**, find **Allow service principals to create and use profiles**.
4. Choose **Disabled**, or choose **Enabled** and scope the setting to **Specific security groups** containing the applications that need this access.
5. Select **Apply**.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#allow-service-principals-to-create-and-use-profiles)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%