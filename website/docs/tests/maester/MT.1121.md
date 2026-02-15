---
title: MT.1121 - AI agents with generative orchestration should have custom instructions
description: Checks all Copilot Studio agents that use generative orchestration for the presence of custom instructions.
slug: /tests/MT.1121
sidebar_class_name: hidden
---

# AI agents with generative orchestration should have custom instructions

## Description

Checks all Copilot Studio agents that use generative orchestration (generative actions enabled) for the presence of custom instructions. Agents without instructions rely entirely on the LLM's default behavior, which increases the risk of prompt injection, off-topic responses, and uncontrolled tool usage.

## How to fix

Open each flagged agent in Copilot Studio and add custom instructions that define the agent's purpose, boundaries, and behavioral constraints. At minimum, instructions should specify what the agent is allowed to do, what topics are off-limits, and how it should handle attempts to override its instructions.

Learn more: [Create and edit custom instructions](https://learn.microsoft.com/en-us/microsoft-copilot-studio/authoring-instructions)

## Prerequisites

This test requires the **Dataverse** service connection. See the [AI Agent Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester AI Agent Security Tests](/docs/tests/maester/ai-agent-setup)
