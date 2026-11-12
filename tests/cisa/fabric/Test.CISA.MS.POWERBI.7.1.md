Sensitivity labels are enabled and employed on sensitive Power BI data according to enterprise policy, as required by SCuBA MS.POWERBI.7.1v1.

This check reuses [CIS.M365.9.1.6](https://maester.dev/docs/tests/CIS.M365.9.1.6) for ScubaGear's automated condition: `EimInformationProtectionEdit.enabled` must be true. Enabled labeling passes and disabled labeling fails; missing or malformed enabled data produces an error. A pass shows only that labels are available: it does not establish that labels are published or used on sensitive content.

Sensitivity labels help users recognize data classification and protect supported export paths, but do not replace item permissions or guarantee protection on every sharing path. Label publication and use on sensitive content require separate evidence; review them with the remediation steps below. No license gate is declared: an absent license must not hide a disabled setting; licensing prerequisites must be reviewed during remediation.

#### Remediation action

1. In [Microsoft Purview](https://purview.microsoft.com), define sensitivity labels and publish label policies to the relevant users and groups under **Solutions** > **Information Protection**. Migrate legacy Azure Information Protection labels to unified labeling if applicable.
2. Verify the baseline's licensing prerequisites: Information Protection Premium P1 or P2 for label application/viewing and Power BI Pro or Premium Per User for users applying labels to Power BI content.
3. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
4. Open **Tenant settings** > **Information protection** > **Allow users to apply sensitivity labels for content** and set it to **Enabled**.
5. Define who can apply and change labels: the entire organization or the appropriate specific security groups. Ensure those users also have the necessary create and edit permissions on their content, then select **Apply**.
6. With data owners, review sensitive reports, dashboards, semantic models (datasets), and dataflows against the enterprise classification and data protection policy. Apply the required labels where supported and check appropriate protection on exports.
7. Retain evidence of published policies, authorized labeling scope, and sensitive-content review for the organization's assessment process; the tenant-setting audit alone cannot establish label use.

#### Related links

* [CISA sensitive-data requirement and implementation instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#7-power-bi-sensitive-data)
* [Enable sensitivity labels in Fabric and Power BI](https://learn.microsoft.com/fabric/enterprise/powerbi/service-security-enable-data-sensitivity-labels)
* [Create and configure sensitivity labels](https://learn.microsoft.com/purview/create-sensitivity-labels)
* [Sensitivity label limitations](https://learn.microsoft.com/power-bi/enterprise/service-security-sensitivity-label-overview)

<!--- Results --->
%TestResult%
