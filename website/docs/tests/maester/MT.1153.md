---
title: MT.1153 - Sensitivity labels are published for files used by Microsoft 365 Copilot
description: Ensures Microsoft Purview sensitivity labels are published and at least one published label is scoped to files so Microsoft 365 Copilot honors and inherits labels onto AI-generated content.
slug: /tests/MT.1153
sidebar_class_name: hidden
---

# Sensitivity labels are published for files used by Microsoft 365 Copilot

## Description

Microsoft 365 Copilot only honors and inherits sensitivity labels onto AI-generated content when sensitivity labels are actually published to users in your tenant and at least one published label is scoped to **files** (SharePoint, OneDrive and Office documents).

Without a published file-scoped label, Copilot has no labelling signal to apply, the most-restrictive label inheritance behaviour cannot run, and DSPM for AI cannot report on label-based oversharing.

The test passes when at least one label policy is published and at least one label has the `File` scope.

## How to fix

1. Open the [Microsoft Purview portal — Information Protection — Labels](https://purview.microsoft.com/informationprotection/labels).
2. Create or edit a sensitivity label and ensure **Files** is selected under "Define the scope for this label".
3. Open **Label policies** and publish the label to the relevant users or groups.

## Prerequisites

This test uses the Security & Compliance PowerShell session.

```powershell
Connect-Maester -Service SecurityCompliance
```

## Learn more

- [Sensitivity labels overview](https://learn.microsoft.com/en-us/purview/sensitivity-labels)
- [Microsoft 365 Copilot data protection and sensitivity labels](https://learn.microsoft.com/en-us/copilot/microsoft-365/microsoft-365-copilot-privacy)
- [How Copilot inherits sensitivity labels](https://learn.microsoft.com/en-us/purview/sensitivity-labels-coauthoring)
