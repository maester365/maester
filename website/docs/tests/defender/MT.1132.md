---
title: MT.1132 - CPU Load Factor should be optimized (20-30%)
description: Verifies that the CPU load factor for scans is set between 20-30% to balance security and performance.
slug: /tests/MT.1132
sidebar_class_name: hidden
---

# CPU Load Factor should be optimized (20-30%)

## Description

Verifies that the CPU load factor for scans is set between 20-30% to balance security and performance.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Scan. Set 'Avg CPU Load Factor' to a value between 20 and 30.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
