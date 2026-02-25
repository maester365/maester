---
title: MT.1120 - AI agents should not use MCP server tools without review
description: Checks all Copilot Studio agents for Model Context Protocol (MCP) server tool integrations that may introduce supply chain risks.
slug: /tests/MT.1120
sidebar_class_name: hidden
---

# AI agents should not use MCP server tools without review

## Description

Checks all Copilot Studio agents for Model Context Protocol (MCP) server tool integrations. MCP tools extend agents with arbitrary external capabilities and may introduce supply chain risks if the MCP server is compromised or untrusted.

## How to fix

Review all MCP server integrations in the flagged agents. Ensure each MCP server endpoint is owned by your organization or a trusted partner, is hosted on infrastructure you control, and uses HTTPS with proper authentication. Consider replacing MCP tools with Power Platform custom connectors that provide DLP policy enforcement and governance controls.

Learn more: [Use MCP servers in Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp)

## Prerequisites

This test evaluates **Copilot Studio** agent configurations via the Dataverse API. See the [Copilot Studio Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester Copilot Studio Security Tests](/docs/tests/maester/ai-agent-setup)
