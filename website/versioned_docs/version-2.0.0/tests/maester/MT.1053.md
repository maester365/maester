---
title: MT.1053 - Intune automatic device clean-up rule is configured.
description: Checks if the intune automatic device clean-up rule is configured.
slug: /tests/MT.1053
sidebar_class_name: hidden
---

# Intune automatic device clean-up rule is configured.

## Description

Set your Intune device cleanup rules to delete Intune MDM enrolled devices that appear inactive, stale, or unresponsive. Intune applies cleanup rules immediately and continuously so that your device records remain current.

## How to fix

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Click **Devices** scroll down to **Organize devices**.
3. Select **Device clean-up rules**.
4. Select **Create**.
5. Set **Name** and **Platfrom**.
6. Enter **30 days or more** depending on your organizational needs.
7. Click **Next**.
8. Click **Create**.

## Learn more

* [Microsoft Intune - Device clean-up rules](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/device-cleanup-rules)
