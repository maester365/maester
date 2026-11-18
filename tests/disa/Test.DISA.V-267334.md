An Intune diagnostic setting sends the Intune audit logs to a log store outside Intune. (DISA Microsoft Intune MDM Service Desktop STIG, V-267334, CAT II).

DISA asks that Intune logs are moved to another server at least every seven days. A diagnostic setting streams them continuously, which meets that.

This test runs [MT.1100](https://maester.dev/docs/tests/MT.1100), which checks that an Intune diagnostic setting includes the audit logs. A site that exports the logs by hand must show that process instead.

#### Remediation action

1. In the [Microsoft Intune admin center](https://intune.microsoft.com), go to **Reports** > **[Diagnostic settings](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/DiagnosticsSettingsBlade)**.
2. Select **Add diagnostic setting**.
3. Select the **AuditLogs** category (and any other Intune logs you need) and send them to a Log Analytics workspace, a storage account, an event hub or a partner solution.
4. Select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop STIG: V-267334](https://cyber.trackr.live/stig/Intune_Service_Desktop/1/1/V-267334)
* [Send Intune log data to storage, event hubs, or Log Analytics](https://learn.microsoft.com/intune/intune-service/fundamentals/review-logs-using-azure-monitor)

<!--- Results --->
%TestResult%
