---
title: MT.1154 - Full Scan Removable Drives should be enabled
description: Verifies that full scans include removable drives (USB) to mitigate USB-based threats.
slug: /tests/MT.1154
sidebar_class_name: hidden
---

# Full Scan Removable Drives should be enabled

## Description

Verifies that full scans include removable drives (USB) to mitigate USB-based threats.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Scan. Ensure 'Allow Full Scan Removable Drive Scanning' is set to 'Allowed'.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
