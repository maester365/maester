Tenant Configuration Management monitors should report no active configuration drift.

Configuration management in Microsoft Entra Tenant Governance, built on the Microsoft Graph Tenant Configuration Management APIs (also called Unified Tenant Configuration Management, UTCM), runs monitors that compare the tenant's settings with a JSON configuration baseline. A baseline can cover more than 200 resource types across Entra, Exchange Online, Intune, Teams, Purview and Defender, such as Conditional Access policies, authentication method policies or transport rules. When a setting no longer matches the baseline, the monitor reports a configuration drift with the current and the desired value of each drifted property.

An active drift means the tenant is no longer in the state you approved. It may be an emergency change that was never written back to the baseline, a change made outside your change process, or an attacker who weakened a policy to keep access. Until a drift is investigated and closed, you cannot rely on the baseline as a description of your security configuration.

This check has one result per monitor (📡), named `MT.1254.<monitor id>`, so each monitor passes or fails on its own and the owner of each baseline sees their own result. A result fails when its monitor reports an active drift; drifts that a later monitor run marked as fixed are not listed. Each result starts with a summary of the monitor, one line per property: its status (🟢 active or ⏸️ inactive with the reason), its last run (outcome, time, duration and the drifts it found, with a link to the 📊 **Monitor results** of the monitor), how often it runs, its number of active drifts and how long the oldest of them has been active, its mode, its description, and when and by whom it was created and last changed. A last run that failed is marked ❌, a monitor that has not run for more than two run intervals is marked ⏰ overdue, and a new monitor that is still waiting for its first run is marked ⏳. The drift follows in one table per resource type, marked with the icon of its workload (🆔 Entra ID, 📧 Exchange Online, 💻 Intune, 💬 Teams, 🔒 Purview, 🛡️ Defender). Each resource (📄), or tenant-wide setting (⚙️) such as the authorization policy or the Exchange organization configuration, has one row per drifted property with the current and the desired value, and the date it was first detected, oldest first. For list values, such as the users excluded from a Conditional Access policy, only the items that differ are shown: 🔴 items that are not in the baseline, and 🟢 items of the baseline that are missing. Entra resources such as Conditional Access policies and groups link to the object itself and are listed on the **Affected objects** page of the report; other resources link to the monitor.

To leave out a monitor that tracks settings you do not want to gate on, disable its result in `maester-config.json` (a `TestSettings` entry with `"Id": "MT.1254.<monitor id>"` and `"Enabled": false`), or run with `-ExcludeTestId MT.1254.<monitor id>`. For monitors with a lot of drift, `MaxDriftsPerMonitor` (default 50), `MaxPropertiesPerResource` (default 5) and `MaximumValueLength` (default 80) keep the result readable; the rest is counted as **+N more**. These can be set for all monitors or for one. When the tenant has no monitor, the check is skipped. When a monitor reports no drift but is inactive (⏸️), its last run did not report success (failed, partially successful or an unknown status), it is overdue, it has not run yet or its runs cannot be read, its result is **Investigate**, because the missing drift may only mean that the settings were not checked.

The connection needs the `ConfigurationMonitoring.Read.All` Microsoft Graph permission. It is included in `Get-MtGraphScope -IncludePreview`. Without it, the check is skipped. Tenant Configuration Management is only available in the worldwide Microsoft Graph service (Commercial and GCC); in other clouds the check is skipped.

**Report confidentiality:** Current and desired configuration values are displayed without secret-specific redaction; length limits are not masking. Treat exported reports as confidential: they can also contain UPNs, names, partner details and privileged relationships. Restrict access and review the content before sharing.

#### Remediation action

1. In the results below, select a monitor to open it in the [Microsoft Entra admin center](https://entra.microsoft.com), or browse to **Tenant Governance** > **Monitors**.
2. Select the **Configuration drifts** tab and open each drift listed in the results.
3. Select the **Drifted properties** value to compare the actual and the expected value, and find out who changed the setting in the audit log of the workload.
4. If the change was not approved, restore the setting to the desired value. If it was approved, update the monitor's baseline to the new value.
5. Wait for the next monitor run (monitors run every six hours by default). It marks the drift as `fixed`.
6. If a monitor is inactive, or its last run failed, check its **Monitor results** and grant the Tenant Configuration Management service principal the permissions it needs.

#### Related links

* [Configuration management in Microsoft Entra Tenant Governance](https://learn.microsoft.com/entra/id-governance/tenant-governance/configuration-management)
* [View monitor results and manage monitors](https://learn.microsoft.com/entra/id-governance/tenant-governance/how-to-see-monitor-results)
* [Set up permissions for tenant monitoring](https://learn.microsoft.com/entra/id-governance/tenant-governance/how-to-set-up-permissions-tenant-monitoring)
* [Microsoft Graph - List configurationDrifts](https://learn.microsoft.com/graph/api/configurationmanagement-list-configurationdrifts?view=graph-rest-1.0)

<!--- Results --->
%TestResult%
