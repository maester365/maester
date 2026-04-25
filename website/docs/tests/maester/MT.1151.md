---
title: MT.1151 - Ensure Managed Installer Rules are configured correctly
description: Checks Intune Endpoint Security Application Control policies for the 'Trust apps from managed installer' setting.
slug: /tests/MT.1151
sidebar_class_name: hidden
---

# Ensure Managed Installer Rules are configured correctly

## Description

Checks Intune Endpoint Security Application Control policies for the **Trust apps from managed installer** setting.

When Managed Installer is enabled in an App Control for Business policy, applications deployed through Intune (or SCCM) are automatically trusted and allowed to run without needing explicit allow rules in the code integrity policy. This dramatically simplifies App Control deployment in enterprise environments.

**Without Managed Installer:**

- Every application must have an explicit allow rule in the App Control policy.
- Line-of-business (LOB) apps deployed via Intune may be blocked unexpectedly.
- Help desk tickets increase due to false positives from legitimate software being blocked.

**With Managed Installer:**

- Apps deployed through Intune are automatically allow-listed at install time.
- Only user-installed, sideloaded, or internet-downloaded apps are subject to policy restrictions.
- Reduces false positives while maintaining security against unauthorized software.

The test passes if at least one App Control for Business policy has **Trust apps from managed installer** enabled.

## How to fix

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Application control**.
3. Edit an existing App Control for Business policy (or create a new one).
4. Under **App Control for Business**, select **Built-in controls**.
5. Set **Trust apps from managed installer** to **Enabled**.
6. Save and assign the policy to your device groups.

> **Note:** Managed Installer works by tagging files written by the Intune Management Extension (IME) process. The App Control policy then trusts any file that was installed by a tagged managed installer process. This is transparent to end users.

## Learn more

- [Configure Managed Installer in Intune](https://learn.microsoft.com/mem/intune/protect/endpoint-security-app-control-policy)
- [Automatically allow apps deployed by a managed installer](https://learn.microsoft.com/windows/security/application-security/application-control/app-control-for-business/design/configure-appcontrol-managed-installer)
- [App Control for Business overview](https://learn.microsoft.com/windows/security/application-security/application-control/app-control-for-business/appcontrol)
