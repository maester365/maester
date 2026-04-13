---
title: MDE.AV13 - Signatures should be checked before scan
description: Verifies that signature definitions are checked and updated before running a scan for zero-day protection.
slug: /tests/MDE.AV13
sidebar_class_name: hidden
---

# Signatures should be checked before scan

## Description

Verifies that signature definitions are checked and updated before running a scan for zero-day protection.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Scan. Ensure 'Check For Signatures Before Running Scan' is enabled.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
