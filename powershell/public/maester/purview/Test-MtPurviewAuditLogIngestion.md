Ensure the Microsoft 365 unified audit log is enabled so tenant activity across Exchange, SharePoint, OneDrive, Teams, Entra ID, Microsoft 365 Copilot and other workloads is captured for Microsoft Purview.

The unified audit log is the **foundation** for Microsoft Purview Audit, eDiscovery, Insider Risk Management, Communication Compliance, and the DSPM for AI activity explorer. Copilot prompt/response activity is one of many signals that flow into it — along with mailbox access, file operations, admin actions, sign-ins and every other workload event.

When `UnifiedAuditLogIngestionEnabled` is `False`:

- Tenant activity is **not** captured anywhere in Purview.
- Purview audit search returns no results.
- eDiscovery cannot find user or workload activity.
- Insider Risk Management policies cannot generate alerts.
- Communication Compliance policies will not match content.
- DSPM for AI activity explorer will be empty and Copilot interactions cannot be reviewed.

The test passes if `Get-AdminAuditLogConfig` returns `UnifiedAuditLogIngestionEnabled = True`.

#### Remediation action:

1. Connect to Exchange Online PowerShell as a Compliance Administrator or higher: `Connect-ExchangeOnline`.
2. Run: `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`.
3. Allow up to 60 minutes for ingestion to begin and confirm by searching the [Microsoft Purview audit search](https://purview.microsoft.com/audit/auditsearch).

#### Related links

- [Microsoft Learn — Turn auditing on or off](https://learn.microsoft.com/en-us/purview/audit-log-enable-disable)
- [Microsoft Learn — Search the audit log](https://learn.microsoft.com/en-us/purview/audit-search)
- [Microsoft Learn — Audit logs for Microsoft 365 Copilot interactions](https://learn.microsoft.com/en-us/purview/audit-copilot)
- [Microsoft Learn — Data Security Posture Management for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)

<!--- Results --->
%TestResult%
