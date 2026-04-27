---
title: MT.1156 - Retention policy is configured for the Microsoft Copilot location
description: Ensures a Microsoft Purview retention policy is enabled for the Microsoft Copilot location to govern how Microsoft 365 Copilot prompts and AI-generated responses are retained or deleted.
slug: /tests/MT.1156
sidebar_class_name: hidden
---

# Retention policy is configured for the Microsoft Copilot location

## Description

Copilot prompts and AI-generated responses are stored in the user's Exchange mailbox and are subject to Microsoft Purview retention. A retention policy targeting the **Microsoft Copilot** location lets the organisation retain Copilot transcripts for a defined period and defensibly dispose of them afterwards.

Without one, Copilot interactions may be retained indefinitely (increasing data subject access request and breach blast-radius), the organisation may fail regulatory obligations for AI interaction record-keeping, and eDiscovery / legal-hold workflows may have inconsistent coverage of AI activity.

The test passes when at least one enabled retention policy targets the Microsoft Copilot location.

## How to fix

1. Open the [Microsoft Purview portal — Data Lifecycle Management — Policies](https://purview.microsoft.com/datalifecyclemanagement/policies).
2. Click **+ New retention policy**.
3. Enable the **Microsoft Copilot** location.
4. Define a retention duration (for example, retain for 1 year then delete) aligned to your records-retention strategy.
5. Apply the policy and turn it on.

## Prerequisites

This test uses the Security & Compliance PowerShell session.

```powershell
Connect-Maester -Service SecurityCompliance
```

## Learn more

- [Retention policies for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/purview/retention-policies-copilot)
- [Learn about retention](https://learn.microsoft.com/en-us/purview/retention)
- [Audit and eDiscovery for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/purview/audit-copilot)
