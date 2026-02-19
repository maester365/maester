---
title: MT.1115 - AI agents should not have risky HTTP configurations
description: Checks all Copilot Studio agents for HTTP actions that connect to non-standard ports or use plain HTTP instead of HTTPS.
slug: /tests/MT.1115
sidebar_class_name: hidden
---

# AI agents should not have risky HTTP configurations

## Description

Checks all Copilot Studio agents for HTTP actions that connect to non-standard ports or non-connector endpoints. HTTP actions to unexpected destinations may indicate data exfiltration, command-and-control communication, or misconfigured integrations.

## How to fix

Review the HTTP request nodes in each flagged agent's topics. Ensure all HTTP requests use HTTPS on standard port 443. Replace direct HTTP calls with Power Platform connectors where possible, as connectors provide built-in governance and DLP policy enforcement.

Learn more: [Configure data policies for agents](https://learn.microsoft.com/microsoft-copilot-studio/admin-data-loss-prevention?tabs=webapp#block-http-requests)

## Prerequisites

This test evaluates **Copilot Studio** agent configurations via the Dataverse API. See the [Copilot Studio Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester Copilot Studio Security Tests](/docs/tests/maester/ai-agent-setup)
