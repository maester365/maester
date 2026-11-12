Service-principal creation and use of profiles is disabled or restricted to specific security groups, as assessed by SCuBA MS.POWERBI.4.2v1.

Profiles support multitenant applications. Limiting eligible cloud application identities reduces the impact of compromised service principals using profiles across customer boundaries. This check runs [CIS.M365.9.1.11](https://maester.dev/docs/tests/CIS.M365.9.1.11), evaluating `AllowServicePrincipalsCreateAndUseProfiles` as disabled or with a nonempty `enabledSecurityGroups` list, matching ScubaGear. Missing or malformed enabled data produces an error. It does not inspect profiles, their permissions, or group membership.

#### Remediation action

1. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
2. Open **Tenant settings** > **Developer settings**.
3. Expand **Allow service principals to create and use profiles**.
4. If no service principal needs profiles, set it to **Disabled**.
5. Otherwise set it to **Enabled**, select **Specific security groups**, and specify groups containing only service principals authorized to create and use profiles.
6. Select **Apply**. Review group membership and profile permissions separately. The tenant restriction affects application identities rather than ordinary end users.

#### Related links

* [CISA Power BI service-principal instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#4-power-bi-service-principals)
* [Fabric profile tenant setting](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#allow-service-principals-to-create-and-use-profiles)
* [Service-principal profiles for multitenancy](https://learn.microsoft.com/power-bi/developer/embedded/embed-multi-tenancy)

<!--- Results --->
%TestResult%
