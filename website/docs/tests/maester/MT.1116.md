---
title: MT.1116 - AI agents should not send email with AI-controlled inputs
description: Checks all Copilot Studio agents for email-sending tools where the recipient, subject, or body may be controlled by AI-generated content.
slug: /tests/MT.1116
sidebar_class_name: hidden
---

# AI agents should not send email with AI-controlled inputs

## Description

Checks all Copilot Studio agents for email-sending tools (such as Office 365 Outlook or SendMail connectors) where the recipient, subject, or body may be controlled by AI-generated content. This presents a risk of data exfiltration via email to attacker-controlled addresses.

## How to fix

Remove email-sending tools from agents that do not have a legitimate business need to send email. For agents that do require email capabilities, ensure recipients are restricted to a fixed list and are not dynamically determined by user input or AI-generated content. Use DLP policies to block the Outlook connector for agents that should not send email.

Learn more: [Configure data policies for agents](https://learn.microsoft.com/microsoft-copilot-studio/admin-data-loss-prevention?tabs=webapp#configure-a-data-policy-in-the-power-platform-admin-center)

## Prerequisites

This test evaluates **Copilot Studio** agent configurations via the Dataverse API. See the [Copilot Studio Security Tests setup guide](/docs/tests/maester/ai-agent-setup) for configuration instructions.

```powershell
Connect-Maester -Service Graph,Dataverse
```

## Learn more

- [Copilot Studio Agent Security Top 10 Risks](https://learn.microsoft.com/microsoft-copilot-studio/guidance/security-top-10)
- [Maester Copilot Studio Security Tests](/docs/tests/maester/ai-agent-setup)
