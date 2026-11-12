Requests review of Content Security Policy (CSP) enforcement for model-driven and canvas Power Apps. ScubaGear audits this requirement manually because the setting is stored per environment, so the result is always **Investigate**. It applies only to environments that have a Dataverse database.

CSP limits the sources a Power App can load content from, which reduces the impact of cross-site scripting and data injection.

#### Remediation action

1. Sign in to the [Power Platform admin center](https://admin.powerplatform.microsoft.com).
2. Select **Environments** and open an environment that has Dataverse.
3. Select **Settings**, then **Product**, then **Privacy + Security**.
4. Turn on **Enforce content security policy for model-driven apps** and **Enforce content security policy for canvas apps**.
5. Turn on **Enable reporting**, then select **Save**.
6. Repeat for each Dataverse environment.

#### Related links

- [CISA SCuBA Power Platform baseline MS.POWERPLATFORM.4.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/powerplatform.md#mspowerplatform4)
- [Content Security Policy in Power Platform](https://learn.microsoft.com/power-platform/admin/content-security-policy)

<!--- Results --->
%TestResult%
