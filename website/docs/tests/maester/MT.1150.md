---
title: MT.1150 - Ensure App Control for Business is enabled
description: Checks Intune Endpoint Security Application Control policies for App Control for Business (formerly WDAC) configurations.
slug: /tests/MT.1150
sidebar_class_name: hidden
---

# Ensure App Control for Business is enabled

## Description

Checks Intune Endpoint Security Application Control policies for **App Control for Business** (formerly Windows Defender Application Control / WDAC) configurations.

App Control for Business restricts which applications and drivers are allowed to run on Windows devices using code integrity policies. This is one of the most effective defenses against malware, ransomware, and unauthorized software because it blocks untrusted executables from running at all — even if they bypass antivirus detection.

Key settings evaluated:

- **Build Options** — Whether the policy uses built-in controls (`built_in_controls_selected`) or a custom uploaded policy (`upload_policy_selected`).
- **Audit Mode** — Whether the policy is in audit mode (logging only) or enforce mode (blocking).
- **Trust apps from managed installer** — Whether apps deployed via Intune/SCCM are automatically trusted.
- **Trust apps with good reputation (ISG)** — Whether apps with good Intelligent Security Graph reputation are trusted.

The test passes if at least one App Control for Business policy exists with build options configured. Policies still in **Audit mode** trigger an informational note recommending a transition to **Enforce mode** after validation.

## How to fix

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Application control**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **App Control for Business**.
5. Enter a policy name (for example, "App Control - Audit Mode").
6. Configure:
   - **App Control for Business**: **Built-in controls**
   - **Audit mode**: **Enabled** (start in audit mode to identify blocked apps)
   - **Trust apps from managed installer**: **Enabled**
   - **Trust apps with good reputation**: **Disabled** (optional — ISG adds convenience but reduces strictness)
7. Assign the policy to a test device group first.
8. Monitor blocked / audited apps in **Microsoft Defender for Endpoint** > **Reports** > **Application control**.
9. After validating that legitimate apps are not being blocked, transition to **Enforce mode**.

## Learn more

- [App Control for Business in Intune](https://learn.microsoft.com/mem/intune/protect/endpoint-security-app-control-policy)
- [Application Control for Windows](https://learn.microsoft.com/windows/security/application-security/application-control/app-control-for-business/appcontrol)
- [Configure Managed Installer and ISG options](https://learn.microsoft.com/windows/security/application-security/application-control/app-control-for-business/design/configure-appcontrol-managed-installer)
