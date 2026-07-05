---
title: MT.1172 - Unified audit log ingestion is enabled
description: Ensures the Microsoft 365 unified audit log is enabled so tenant activity across Exchange, SharePoint, OneDrive, Teams, Entra ID, Microsoft 365 Copilot and other workloads is captured for Microsoft Purview.
slug: /tests/MT.1172
sidebar_class_name: hidden
---

# Unified audit log ingestion is enabled

## Description

The **unified audit log** is the foundation for Microsoft Purview Audit, eDiscovery, Insider Risk Management, Communication Compliance, and the DSPM for AI activity explorer. Copilot prompt/response activity is one of many signals that flow into it — along with mailbox access, file operations, admin actions, sign-ins and every other workload event.

When `UnifiedAuditLogIngestionEnabled` is `False`, tenant activity is not captured anywhere in Purview — audit search returns no results, eDiscovery cannot find user or workload activity, Insider Risk and Communication Compliance policies cannot fire, and DSPM for AI activity explorer is empty.

The test passes when `Get-AdminAuditLogConfig` returns `UnifiedAuditLogIngestionEnabled = True`.

## How to fix

1. Connect to Exchange Online as a Compliance Administrator: `Connect-ExchangeOnline`.
2. Run: `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`.
3. Allow up to 60 minutes for ingestion to begin and verify in the [Microsoft Purview audit search](https://purview.microsoft.com/audit/auditsearch).

## Prerequisites

This test uses Exchange Online PowerShell.

```powershell
Connect-Maester -Service ExchangeOnline
```

## Learn more

- [Turn auditing on or off](https://learn.microsoft.com/en-us/purview/audit-log-enable-disable)
- [Search the audit log](https://learn.microsoft.com/en-us/purview/audit-search)
- [Audit logs for Microsoft 365 Copilot interactions](https://learn.microsoft.com/en-us/purview/audit-copilot)
- [Data Security Posture Management for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
