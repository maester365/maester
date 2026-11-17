Power BI **Publish to web** is disabled, as assessed by SCuBA MS.POWERBI.1.1v1.

Public embed URLs require no sign-in and can expose report data to anyone, including an attacker collecting cloud data. This check reads the tenant's `PublishToWeb` setting and passes only when `enabled` is false. Missing, duplicated, or non-Boolean data produces an error, not a pass.

Unlike [CIS.M365.9.1.4](https://maester.dev/docs/tests/CIS.M365.9.1.4), ScubaGear does not accept enabled publishing restricted to groups or existing embed codes. An agency-approved mission exception must be assessed and documented separately; it does not turn an enabled setting into an automated pass.

#### Remediation action

1. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
2. Open **Tenant settings** > **Export and sharing settings**.
3. Expand **Publish to web** and set it to **Disabled**.
4. Select **Apply**. Report publishers using public embedding will need an approved authenticated sharing alternative.
5. If the agency mission requires public publishing, document the exception and restrict publishing to specific security groups. Review public reports and embed codes separately; this audit does not inventory their content.

#### Related links

* [CISA Power BI baseline and implementation instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#1-publish-to-web)
* [ScubaGear Power BI audit policies](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/PowerBIConfig.rego)
* [Publish to web tenant settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-export-sharing#publish-to-web)

<!--- Results --->
%TestResult%
