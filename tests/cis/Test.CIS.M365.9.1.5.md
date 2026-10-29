R and Python visuals are disabled for the Fabric tenant.

These visuals execute scripts when reports render. Turning off the tenant setting reduces the code-execution surface in reports; Microsoft does not provide a security-group scope for this setting.

#### Remediation action

1. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
2. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
3. Under **R and Python visuals settings**, find **Interact with and share R and Python visuals**.
4. Set the control to **Disabled**, then select **Apply**. This setting applies to the entire organization and can't be limited to groups.
5. Identify reports that depend on these visuals and move them to an approved alternative.

#### Related links

* [R and Python visuals admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-r-python-visuals)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%