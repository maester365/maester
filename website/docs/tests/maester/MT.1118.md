---
title: MT.1118 - AI agents should not use author (maker) authentication for connections
description: Checks all Copilot Studio agents for connector tools that use author (maker) authentication instead of end-user authentication.
slug: /tests/MT.1118
sidebar_class_name: hidden
---

# AI agents should not use author (maker) authentication for connections

## Description

Checks all Copilot Studio agents for connector tools that use author (maker) authentication instead of end-user authentication. When a connection uses author authentication, the agent accesses external services (SharePoint, SQL, etc.) using the bot maker's stored credentials rather than requiring the end user to authenticate. This creates a privilege escalation risk — the agent operates with the maker's permissions regardless of who is chatting with it.

## How to fix

In Copilot Studio, review the agent's tools and change each connector's authentication setting from **Agent author authentication** to **User authentication**. This ensures the agent accesses external services using the chatting user's own credentials and permission scope.

Learn more: [Configure user authentication in Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/configure-enduser-authentication)

## Prerequisites

This test evaluates **Copilot Studio** agent configurations via the Dataverse API. See the [Copilot Studio Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester Copilot Studio Security Tests](/docs/tests/maester/ai-agent-setup)
