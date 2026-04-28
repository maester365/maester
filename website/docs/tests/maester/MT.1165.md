---
title: MT.1165 - Network Protection should be enabled
description: Verifies that network protection is enabled to block connections to malicious domains and IP addresses.
slug: /tests/MT.1165
sidebar_class_name: hidden
---

# Network Protection should be enabled

## Description

Verifies that network protection is enabled to block connections to malicious domains and IP addresses.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus. Ensure 'Enable Network Protection' is set to 'Enabled (block mode)'.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
