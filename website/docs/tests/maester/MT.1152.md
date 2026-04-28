---
title: MT.1152 - Script Scanning should be enabled
description: Verifies that script scanning is enabled to block malicious scripts during execution.
slug: /tests/MT.1152
sidebar_class_name: hidden
---

# Script Scanning should be enabled

## Description

Verifies that script scanning is enabled to block malicious scripts during execution.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Real-time Protection. Ensure 'Allow Script Scanning' is set to 'Allowed'.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
