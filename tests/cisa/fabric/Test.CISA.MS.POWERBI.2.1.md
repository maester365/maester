Power BI guest access is disabled or restricted to specific security groups, as assessed by SCuBA MS.POWERBI.2.1v1.

Limiting entry to the workload reduces exposure from compromised external cloud accounts. This check runs [CIS.M365.9.1.1](https://maester.dev/docs/tests/CIS.M365.9.1.1): the same `AllowGuestUserToAccessSharedContent` tenant setting and the same ScubaGear condition, disabled or a nonempty `enabledSecurityGroups` list. Missing or malformed enabled data produces an error. It does not assess group membership, mission justification, or individual item permissions.

#### Remediation action

1. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
2. Open **Tenant settings** > **Export and sharing settings**.
3. In commercial tenants, expand **Guest users can access Microsoft Fabric**. In GCC, GCC High, and DoD, use **Allow Azure Active Directory guest users to access Power BI**.
4. Set the feature to **Disabled** unless the agency mission requires guest access.
5. If guest access is required, set it to **Enabled**, select **Specific security groups**, and add the approved groups. Create dedicated groups if needed; review their membership and retain the mission justification.
6. Select **Apply**. Coordinate with affected collaborators because guests outside the allowed scope lose this access capability.

#### Related links

* [CISA Power BI guest access instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#2-power-bi-guest-access)
* [Fabric export and sharing settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [Power BI guest collaboration](https://learn.microsoft.com/power-bi/enterprise/service-admin-azure-ad-b2b)

<!--- Results --->
%TestResult%
