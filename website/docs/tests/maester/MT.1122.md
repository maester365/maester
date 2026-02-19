---
title: MT.1122 - AI agents should not have orphaned ownership
description: Checks all Copilot Studio agents for those whose owner accounts no longer exist or are disabled in Entra ID.
slug: /tests/MT.1122
sidebar_class_name: hidden
---

# AI agents should not have orphaned ownership

## Description

Checks all Copilot Studio agents for those whose owner accounts no longer exist or are disabled in Entra ID. Orphaned agents lack active governance and may drift from security policies without anyone responsible for maintaining them.

## How to fix

Assign an active user as the owner of each orphaned agent in Copilot Studio. If the agent is no longer needed, unpublish or delete it.

Learn more: [Agent Registry in the Microsoft 365 admin center](https://learn.microsoft.com/microsoft-365/admin/manage/agent-registry) and [share agents with other users](https://learn.microsoft.com/microsoft-copilot-studio/admin-share-bots?tabs=web)

## Prerequisites

This test evaluates **Copilot Studio** agent configurations via the Dataverse API. See the [Copilot Studio Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester Copilot Studio Security Tests](/docs/tests/maester/ai-agent-setup)
