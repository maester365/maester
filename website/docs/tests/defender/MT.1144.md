---
title: MT.1144 - Catch-up Full Scan should be disabled
description: Verifies that catch-up full scan is disabled to avoid excessive system load when devices come back online.
slug: /tests/MT.1144
sidebar_class_name: hidden
---

# Catch-up Full Scan should be disabled

## Description

Verifies that catch-up full scan is disabled to avoid excessive system load when devices come back online.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Scan. Ensure 'Disable Catchup Full Scan' is set to 'Enabled' (meaning catch-up is disabled).

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
