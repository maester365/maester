---
title: MT.1145 - Catch-up Quick Scan should be disabled
description: Verifies that catch-up quick scan is disabled to avoid excessive system load.
slug: /tests/MT.1145
sidebar_class_name: hidden
---

# Catch-up Quick Scan should be disabled

## Description

Verifies that catch-up quick scan is disabled to avoid excessive system load.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Scan. Ensure 'Disable Catchup Quick Scan' is set to 'Enabled' (meaning catch-up is disabled).

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
