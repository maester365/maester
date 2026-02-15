---
title: MT.1117 - Published AI agents should not be dormant
description: Checks all published Copilot Studio agents for those that have not been modified or republished within a configurable threshold (default 180 days).
slug: /tests/MT.1117
sidebar_class_name: hidden
---

# Published AI agents should not be dormant

## Description

Checks all published Copilot Studio agents for those that have not been modified or republished within a configurable threshold (default 180 days). Dormant agents may have outdated configurations, unpatched vulnerabilities, or stale permissions that present unnecessary risk.

## How to fix

Review dormant agents and either update their configuration to align with current policies, or unpublish/delete agents that are no longer needed.

Learn more: [Delete agents programmatically](https://learn.microsoft.com/microsoft-copilot-studio/admin-api-delete) and [delete an agent in Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/authoring-first-bot#delete-an-agent)

## Prerequisites

This test requires the **Dataverse** service connection. See the [AI Agent Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester AI Agent Security Tests](/docs/tests/maester/ai-agent-setup)
