---
title: MT.1054 - Intune built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'.
description: Checks if the intune built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'
slug: /tests/MT.1054
sidebar_class_name: hidden
---

# Intune built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'.

## Description

Set your Intune built-in Device Compliance Policy to mark devices with no compliance policy assigned as 'Not compliant'.
This ensures that new devices that do not have any policies assigned are not compliant per default.

## How to fix

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Click **Devices** scroll down to **Manage devices**.
3. Select **Compliance** and Select **Compliance settings**.
4. Toggle **Mark devices with no compliance policy assigned as** to **Not compliant**.
5. Click **Save**.

## Learn more
* [Microsoft Intune - Compliance](https://intune.microsoft.com/?ref=AdminCenter#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
* [Microsoft Learn - Compliance policy settings](https://learn.microsoft.com/de-de/mem/intune/protect/device-compliance-get-started#compliance-policy-settings)