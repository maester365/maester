---
title: MT.1114 - AI agents should require user authentication
description: Checks all Copilot Studio agents for those configured with no user authentication, allowing anonymous access.
slug: /tests/MT.1114
sidebar_class_name: hidden
---

# AI agents should require user authentication

## Description

Checks all Copilot Studio agents for weak or missing authentication. Flags agents with no authentication configured, as well as agents where authentication is configured but "Require users to sign in" is not enabled.

## How to fix

1. In Copilot Studio, open the agent settings and configure authentication to use **Authenticate with Microsoft** or **Authenticate manually**.
2. Enable **Require users to sign in** to ensure every user authenticates before interacting with the agent.

Learn more: [Configure user authentication in Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/configuration-end-user-authentication#required-user-sign-in-and-agent-sharing)

## Prerequisites

This test evaluates **Copilot Studio** agent configurations via the Dataverse API. See the [Copilot Studio Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester Copilot Studio Security Tests](/docs/tests/maester/ai-agent-setup)
