Power BI R and Python visual interactions are disabled, as assessed by SCuBA MS.POWERBI.6.1v1.

User-authored visual scripts can introduce code-execution and privacy risks through report content. This check runs [CIS.M365.9.1.5](https://maester.dev/docs/tests/CIS.M365.9.1.5), passing only when `RScriptVisual.enabled` is false, matching ScubaGear. This is a tenant feature restriction, not an assessment of individual script safety. Missing or malformed enabled data produces an error.

#### Remediation action

1. Identify reports using R or Python visuals and coordinate supported replacement visuals with their owners. Some users will need to change reports or workflows.
2. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
3. Open **Tenant settings** > **R and Python visuals settings**.
4. Expand **Interact with and share R and Python visuals** and set it to **Disabled**.
5. Select **Apply** and validate affected reports. ScubaGear does not treat enabled interactions restricted to security groups as a pass.

#### Related links

* [CISA R and Python implementation instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#6-python-and-r-visual-sharing)
* [R and Python visuals admin settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-r-python-visuals)
* [Power BI Python visuals](https://learn.microsoft.com/power-bi/connect-data/desktop-python-visuals)

<!--- Results --->
%TestResult%
