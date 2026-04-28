3.1.1 (L1) Ensure Microsoft 365 audit log search is Enabled

When audit log search is enabled in the Microsoft Purview compliance portal, user and admin activity within the organization is recorded in the audit log and retained for 180 days by default. However, some organizations may prefer to use a third-party security information and event management (SIEM) application to access their auditing data. In this scenario, a global admin can choose to turn off audit log search in Microsoft 365.

#### Rationale

Enabling audit log search in the Microsoft Purview compliance portal can help organizations improve their security posture, meet regulatory compliance requirements, respond to security incidents, and gain valuable operational insights

#### Remediation action:

1. Navigate to [Microsoft 365 Purview](https://purview.microsoft.com).
2. Select **Solutions** and then **Audit** to open the audit search.
3. Click blue bar **Start recording user and admin activity**.
4. Click **Yes** on the dialog box to confirm.

##### PowerShell

1. Connect to Exchange Online using `Connect-ExchangeOnline`.
2. Run the following PowerShell command:
```powershell
Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true
```

#### Related links

* [Microsoft 365 Purview](https://purview.microsoft.com)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Page 149](https://www.cisecurity.org/benchmark/microsoft_365)
* [Turn auditing on or off](https://learn.microsoft.com/en-us/purview/audit-log-enable-disable?view=o365-worldwide&tabs=microsoft-purview-portal)
* [Set-AdminAuditLogConfig](https://learn.microsoft.com/en-us/powershell/module/exchangepowershell/set-adminauditlogconfig?view=exchange-ps)
* [Verify the auditing status for your organization](https://learn.microsoft.com/en-us/purview/audit-log-enable-disable?view=o365-worldwide&tabs=microsoft-purview-portal#verify-the-auditing-status-for-your-organization)

<!--- Results --->
%TestResult%