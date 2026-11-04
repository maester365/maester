Resource-key authentication is blocked for Fabric streaming and push datasets.

Resource keys are shared credentials rather than individual identities. Blocking them reduces reliance on reusable keys and improves attribution for API access.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **Developer settings**.
4. Set **Block ResourceKey Authentication** to **Enabled**.
5. Select **Apply** and update any clients that still send data with resource keys to use identity-based authentication.

#### Related links

* [Developer admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#block-resourcekey-authentication)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%