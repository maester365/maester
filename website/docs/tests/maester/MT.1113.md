---
title: MT.1113 - AI agents should not be shared with broad access control policies
description: Checks all Copilot Studio agents for those with access control set to "My organization" or that have "Multitenant support" enabled, which allows any user (or users across tenants) to interact with the agent.
slug: /tests/MT.1113
sidebar_class_name: hidden
---

# AI agents should not be shared with broad access control policies

## Description

Checks all Copilot Studio agents that are shared to **My organization** with access for everyone, or **Multitenant support** enabled, which allows any user (or users across tenants) to interact with the agent.

Agents with broad access control increase the risk of data exposure, unauthorized use of connected systems, and prompt injection attacks from untrusted users.

## How to fix

In Copilot Studio, go to the agents overview and click on the three dots (`...`) and "share". From here, select "My organization" and make sure it's set to **No permissions, unless specified**. Then, in the specific agents settings, go to "Security" and "Authentication" and make sure "Multi-tenant support" is toggled **off**.

Learn more: [Control how agents are shared](https://learn.microsoft.com/microsoft-copilot-studio/admin-sharing-controls-limits) and [share agents with other users](https://learn.microsoft.com/microsoft-copilot-studio/admin-share-bots?tabs=web)

## Prerequisites

This test requires the **Dataverse** service connection. See the [AI Agent Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester AI Agent Security Tests](/docs/tests/maester/ai-agent-setup)
