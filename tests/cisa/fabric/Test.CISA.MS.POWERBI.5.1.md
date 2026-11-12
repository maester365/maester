ResourceKey-based authentication is blocked for Power BI streaming and push datasets, as assessed by SCuBA MS.POWERBI.5.1v1.

A resource key in a URL can authorize data writes without an Entra OAuth bearer token. Blocking this shared-key path requires an identity-based authentication alternative. This check runs [CIS.M365.9.1.9](https://maester.dev/docs/tests/CIS.M365.9.1.9), passing only when `BlockResourceKeyAuthentication.enabled` is true, matching ScubaGear. Missing or malformed enabled data produces an error.

The setting applies tenant-wide, not to selected groups. An approved streaming or push use case is a separately documented exception, not an automated pass.

#### Remediation action

1. Identify integrations that send data using resource keys and coordinate migration to an approved identity-based authentication method with their owners.
2. Sign in to the [Fabric / Power BI admin portal](https://app.powerbi.com/admin-portal) as a Fabric administrator. For government clouds, use the corresponding Power BI portal.
3. Open **Tenant settings** > **Developer settings**.
4. Expand **Block ResourceKey authentication** and set it to **Enabled**, as directed by the SCuBA implementation procedure.
5. Select **Apply**. Pilot the integration changes because resource-key clients will no longer be able to push data using that authentication path.
6. If a specific use case merits resource keys, retain its justification, authorization, and risk review. The enabled blocking condition remains the automated audit standard.

#### Related links

* [CISA resource-key implementation instructions](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerbi.md#5-power-bi-resource-key-authentication)
* [Fabric developer settings](https://learn.microsoft.com/fabric/admin/service-admin-portal-developer#block-resourcekey-authentication)
* [Power BI real-time streaming](https://learn.microsoft.com/power-bi/connect-data/service-real-time-streaming)

<!--- Results --->
%TestResult%
