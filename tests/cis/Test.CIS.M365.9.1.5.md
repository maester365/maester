R and Python visuals are disabled for the Fabric tenant.

These visuals execute scripts when reports render. Turning off the tenant setting reduces the code-execution surface in reports; Microsoft does not provide a security-group scope for this setting.

#### Remediation action

1. Sign in to the [Microsoft Fabric admin portal](https://app.powerbi.com/admin-portal) with a Fabric administrator account.
2. Select **Tenant settings**.
3. Scroll to **R and Python visuals settings**.
4. Set **Interact with and share R and Python visuals** to **Disabled**. This setting applies to the entire organization and can't be limited to groups.
5. Select **Apply**.
6. Identify reports that depend on these visuals and move them to an approved alternative.

#### Related links

* [R and Python visuals admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-r-python-visuals)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%