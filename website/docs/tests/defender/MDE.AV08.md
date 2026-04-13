---
title: MDE.AV08 - Full Scan Mapped Drives should be disabled for performance
description: Verifies that full scans of mapped network drives are disabled for performance optimization, as network files are scanned separately via real-time scanning.
slug: /tests/MDE.AV08
sidebar_class_name: hidden
---

# Full Scan Mapped Drives should be disabled for performance

## Description

Verifies that full scans of mapped network drives are disabled for performance optimization, as network files are scanned separately via real-time scanning.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Scan. Ensure 'Allow Full Scan On Mapped Network Drives' is set to 'Not Allowed'.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
