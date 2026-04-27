---
title: MT.1154 - Insider Risk Management policy for Risky AI usage is enabled
description: Ensures a Microsoft Purview Insider Risk Management policy from the Risky AI usage template is configured and enabled so risky Microsoft 365 Copilot and AI-app interactions generate triageable alerts.
slug: /tests/MT.1154
sidebar_class_name: hidden
---

# Insider Risk Management policy for Risky AI usage is enabled

## Description

Microsoft Purview Insider Risk Management ships a dedicated **Risky AI usage** policy template that detects jailbreak attempts, harmful generations, sensitive-content extraction prompts and anomalous AI interaction patterns inside Microsoft 365 Copilot and other AI apps captured by DSPM for AI.

Without this policy enabled, risky AI signals are silently lost and reviewers have no triage queue for AI misuse.

The test passes when at least one Insider Risk policy with an AI-related scenario / template is enabled.

## How to fix

1. Open the [Microsoft Purview portal — Insider Risk Management — Policies](https://purview.microsoft.com/insiderriskmgmt/policies).
2. Click **+ Create policy** and choose the **Risky AI usage** template.
3. Define users in scope, reviewers, and indicator thresholds.
4. **Enable** the policy.

## Prerequisites

Requires Microsoft 365 E5 or the Insider Risk Management add-on.

```powershell
Connect-Maester -Service SecurityCompliance
```

## Learn more

- [Insider Risk Management policies](https://learn.microsoft.com/en-us/purview/insider-risk-management-policies)
- [Detect risky use of AI with Insider Risk Management](https://learn.microsoft.com/en-us/purview/insider-risk-management-policy-templates)
- [Microsoft Purview AI Hub & DSPM for AI](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
