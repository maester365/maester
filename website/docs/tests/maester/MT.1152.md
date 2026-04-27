---
title: MT.1152 - Unified audit log ingestion is enabled for AI activity
description: Ensures the Microsoft 365 unified audit log is enabled so Microsoft 365 Copilot, Security Copilot and other AI app prompts and responses are captured for downstream Purview AI controls.
slug: /tests/MT.1152
sidebar_class_name: hidden
---

# Unified audit log ingestion is enabled for AI activity

## Description

Microsoft Purview Data Security Posture Management (DSPM) for AI, the Risky AI usage Insider Risk Management template, eDiscovery searches that include Copilot interactions, and Communication Compliance policies for Copilot all depend on the **unified audit log** being enabled.

When `UnifiedAuditLogIngestionEnabled` is `False`, Microsoft 365 Copilot prompts and responses are not captured anywhere in the tenant — DSPM for AI activity explorer is empty, Risky AI usage policies cannot fire alerts, and eDiscovery cannot find Copilot transcripts.

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
- [Audit logs for Microsoft 365 Copilot interactions](https://learn.microsoft.com/en-us/purview/audit-copilot)
- [Data Security Posture Management for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
