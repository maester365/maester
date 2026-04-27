Ensure the Microsoft 365 unified audit log is enabled so Microsoft 365 Copilot, Security Copilot, Copilot Studio and Entra-registered AI app prompts and responses are captured for downstream Purview AI controls.

The unified audit log is the **prerequisite** for the Microsoft Purview Data Security Posture Management (DSPM) for AI activity explorer, the Risky AI usage Insider Risk Management template, eDiscovery searches that include Copilot interactions, and Communication Compliance policies that monitor Copilot prompts/responses.

When `UnifiedAuditLogIngestionEnabled` is `False`:

- AI prompts and responses are **not** captured anywhere in the tenant.
- DSPM for AI activity explorer will be empty.
- Risky AI usage Insider Risk policies cannot generate alerts.
- eDiscovery cannot find Copilot transcripts.
- Communication Compliance for Copilot interactions will not match.

The test passes if `Get-AdminAuditLogConfig` returns `UnifiedAuditLogIngestionEnabled = True`.

#### Remediation action:

1. Connect to Exchange Online PowerShell as a Compliance Administrator or higher: `Connect-ExchangeOnline`.
2. Run: `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`.
3. Allow up to 60 minutes for ingestion to begin and confirm by searching the [Microsoft Purview audit search](https://purview.microsoft.com/audit/auditsearch).

#### Related links

- [Microsoft Learn — Turn auditing on or off](https://learn.microsoft.com/en-us/purview/audit-log-enable-disable)
- [Microsoft Learn — Data Security Posture Management for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
- [Microsoft Learn — Audit logs for Microsoft 365 Copilot interactions](https://learn.microsoft.com/en-us/purview/audit-copilot)

<!--- Results --->
%TestResult%
