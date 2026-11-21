An Intune diagnostic setting sends the Intune audit logs to a log store outside Intune. (DISA Microsoft Intune MDM Service Desktop and Mobile STIG, V-273868, CAT II).

Intune keeps its audit logs for a limited time and only in the Intune admin center. Sending them to Azure Monitor or a SIEM keeps them and lets the security team review and alert on changes.

The STIG accepts a third-party log server or Azure Monitor. This test runs [MT.1100](https://maester.dev/docs/tests/MT.1100), which checks that an Intune diagnostic setting includes the audit logs; logs sent another way must be checked by hand.

#### Remediation action

1. In the [Microsoft Intune admin center](https://intune.microsoft.com), go to **Reports** > **[Diagnostic settings](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/DiagnosticsSettingsBlade)**.
2. Select **Add diagnostic setting**.
3. Select the **AuditLogs** category (and any other Intune logs you need) and send them to a Log Analytics workspace, a storage account, an event hub or a partner solution.
4. Select **Save**.

#### Related links

* [DISA Microsoft Intune MDM Service Desktop and Mobile STIG: V-273868](https://cyber.trackr.live/stig/Intune_MDM_Service_Desktop_&_Mobile/1/2/V-273868)
* [Send Intune log data to storage, event hubs, or Log Analytics](https://learn.microsoft.com/intune/intune-service/fundamentals/review-logs-using-azure-monitor)

<!--- Results --->
%TestResult%
