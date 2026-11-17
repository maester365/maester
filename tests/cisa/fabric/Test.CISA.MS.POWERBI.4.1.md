Service-principal access to Fabric public APIs is disabled or limited to specific security groups, as assessed by SCuBA MS.POWERBI.4.1v1.

Restricting the setting limits which compromised cloud application identities can use workload APIs. This check runs [CIS.M365.9.1.10](https://maester.dev/docs/tests/CIS.M365.9.1.10), checking `ServicePrincipalAccessPermissionAPIs` as disabled or with a nonempty `enabledSecurityGroups` list, matching ScubaGear. Missing or malformed enabled data produces an error.

This is not the separate setting for read-only admin APIs or the setting for creating workspaces, connections, and deployment pipelines. The audit does not inspect group membership, credentials, or permissions on individual items.

#### Remediation action

1. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
2. Open **Tenant settings** > **Developer settings**.
3. Expand **Service principals can call Fabric public APIs**.
4. If no service principal needs these APIs, set the feature to **Disabled**.
5. Otherwise set it to **Enabled**, select **Specific security groups**, and specify dedicated groups containing the authorized service principals.
6. Select **Apply** and review group membership and application access regularly. The restriction concerns application identities; it does not change ordinary end-user workflows.
7. Where service principals use credentials, follow the baseline's recommendation to store them in a key vault with appropriately assigned access policies and regularly reviewed permissions. Credential storage is a separate human assessment.

#### Related links

* [CISA Power BI service-principal instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#4-power-bi-service-principals)
* [Fabric developer settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#service-principals-can-call-fabric-public-apis)
* [Power BI service-principal embedding](https://learn.microsoft.com/power-bi/developer/embedded/embed-service-principal)

<!--- Results --->
%TestResult%
