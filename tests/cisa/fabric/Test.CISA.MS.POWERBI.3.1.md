Power BI external invitations are disabled or restricted to specific security groups, as assessed by SCuBA MS.POWERBI.3.1v1.

Restricting invitations reduces uncontrolled creation of external guest accounts through sharing workflows. This check runs [CIS.M365.9.1.2](https://maester.dev/docs/tests/CIS.M365.9.1.2), evaluating `ExternalSharingV2` as disabled or with a nonempty `enabledSecurityGroups` list, matching ScubaGear. It does not review approved group membership or mission exceptions. Missing or malformed enabled data produces an error.

Disabling invitations does not remove existing guests, their existing item access, or their appearance in user pickers.

#### Remediation action

1. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
2. Open **Tenant settings** > **Export and sharing settings**.
3. Expand **Users can invite guest users to collaborate through item sharing and permissions**.
4. Set it to **Disabled** unless the agency mission requires invitations through Power BI.
5. If invitations are needed, set it to **Enabled**, select **Specific security groups**, and specify groups containing only approved inviters. Create groups if needed and retain mission justification.
6. Select **Apply**. Notify affected users that new invitations must follow the approved workflow.
7. Review existing guest access separately if that access is no longer required.

#### Related links

* [CISA Power BI invitation instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#3-power-bi-external-invitations)
* [Fabric export and sharing settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing)
* [Power BI guest collaboration](https://learn.microsoft.com/power-bi/enterprise/service-admin-azure-ad-b2b)

<!--- Results --->
%TestResult%
