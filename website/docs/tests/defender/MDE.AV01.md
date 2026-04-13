---
title: MDE.AV01 - Archive Scanning should be enabled
description: Verifies that archive scanning (scanning within compressed/archive files) is enabled in Microsoft Defender Antivirus Intune policies.
slug: /tests/MDE.AV01
sidebar_class_name: hidden
---

# Archive Scanning should be enabled

## Description

Verifies that archive scanning (scanning within compressed/archive files) is enabled in Microsoft Defender Antivirus Intune policies.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus. Ensure 'Allow Archive Scanning' is set to 'Allowed'.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
