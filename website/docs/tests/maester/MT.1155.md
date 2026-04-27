---
title: MT.1155 - DLP policy is configured for the Microsoft 365 Copilot location
description: Ensures a Microsoft Purview Data Loss Prevention policy is enabled for the Microsoft 365 Copilot location to block Copilot from summarising or surfacing files containing sensitive information.
slug: /tests/MT.1155
sidebar_class_name: hidden
---

# DLP policy is configured for the Microsoft 365 Copilot location

## Description

Microsoft Purview Data Loss Prevention exposes a **Microsoft 365 Copilot** location that lets you block Copilot from summarising or surfacing files containing sensitive information types (PII, PCI, PHI, secrets, regulated data) or labelled content the requesting user can access but should not have AI summarise.

Without a DLP policy on the Copilot location, Copilot can paraphrase and expose sensitive content from any file the requesting user can read — accelerating oversharing risk through AI-assisted workflows.

The test passes when at least one **enabled, non-simulation** DLP policy targets the Microsoft 365 Copilot location.

## How to fix

1. Open the [Microsoft Purview portal — Data Loss Prevention — Policies](https://purview.microsoft.com/datalossprevention/policies).
2. Click **+ Create policy**.
3. Under **Locations**, enable **Microsoft 365 Copilot**.
4. Configure rules matching your sensitive information types or sensitivity labels (Confidential, Highly Confidential).
5. Set **Mode** to **Turn the policy on immediately**.

## Prerequisites

Requires Exchange Online + Security & Compliance PowerShell sessions and a Microsoft Purview DLP licence.

```powershell
Connect-Maester -Service ExchangeOnline,SecurityCompliance
```

## Learn more

- [DLP for Microsoft 365 Copilot](https://learn.microsoft.com/en-us/purview/dlp-microsoft365-copilot-learn-about)
- [Create a DLP policy](https://learn.microsoft.com/en-us/purview/dlp-create-deploy-policy)
- [Microsoft 365 Copilot oversharing assessment](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
