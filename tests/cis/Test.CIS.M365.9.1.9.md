Resource-key authentication is blocked for Fabric streaming and push datasets.

Resource keys are shared credentials rather than individual identities. Blocking them reduces reliance on reusable keys and improves attribution for API access.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **Developer settings**, find **Block ResourceKey Authentication** and set it to **Enabled**.
4. Select **Apply** and update any clients that still send data with resource keys to use identity-based authentication.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#block-resourcekey-authentication)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%