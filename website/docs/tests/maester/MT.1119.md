---
title: MT.1119 - AI agents should not have hard-coded credentials in topics
description: Scans all Copilot Studio agent topics for patterns that suggest hard-coded credentials, API keys, connection strings, or secrets.
slug: /tests/MT.1119
sidebar_class_name: hidden
---

# AI agents should not have hard-coded credentials in topics

## Description

Scans all Copilot Studio agent topics for patterns that suggest hard-coded credentials, API keys, connection strings, or secrets. Hard-coded credentials in agent topics can be extracted by prompt injection attacks and often persist after key rotation is performed elsewhere.

## How to fix

Replace all hard-coded credentials with secure alternatives. Use Power Platform environment variables for configuration values and Azure Key Vault for secrets. Configure custom connectors with proper OAuth or API key authentication that stores credentials outside the agent topic definition.

Learn more: [Use environment variables in Power Platform](https://learn.microsoft.com/en-us/power-apps/maker/data-platform/environmentvariables)

## Prerequisites

This test requires the **Dataverse** service connection. See the [AI Agent Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester AI Agent Security Tests](/docs/tests/maester/ai-agent-setup)
