Users can apply Microsoft Purview sensitivity labels to supported Fabric content.

This setting enables label application in Fabric. It does not confirm that labels are published to users or that all sharing and export paths enforce label protection; the setting applies to supported exports.

#### Remediation action

1. Confirm that sensitivity labels are configured and published to the intended users, and that the required licensing prerequisites are met.
2. Sign in to [Microsoft Fabric](https://app.fabric.microsoft.com) with a Fabric administrator account.
3. Select **OneLake catalog** > **Govern** > **Configurations** > **Tenant settings**. If these options aren't available in your region, select **Settings** > **Admin portal** > **Tenant settings**.
4. Under **Information protection**, enable **Allow users to apply sensitivity labels for content**. Select the intended user scope and then select **Apply**.

#### Related links

* [Information protection tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-information-protection)
* [Sensitivity labels in Power BI](https://learn.microsoft.com/power-bi/enterprise/service-security-sensitivity-label-overview)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%