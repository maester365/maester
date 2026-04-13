---
title: MDE.AV20 - Tamper Protection should be enabled tenant-wide
description: Manual review required. Verifies that tamper protection is enabled at the tenant level to prevent unauthorized changes to security settings. This setting is managed in the Microsoft Defender XDR portal, not via Intune.
slug: /tests/MDE.AV20
sidebar_class_name: hidden
---

# Tamper Protection should be enabled tenant-wide

## Description

Manual review required. Verifies that tamper protection is enabled at the tenant level to prevent unauthorized changes to security settings. This setting is managed in the Microsoft Defender XDR portal, not via Intune.

## How to fix

1. Navigate to Microsoft Defender XDR portal (security.microsoft.com).
2. Go to Settings > Endpoints > Advanced Features.
3. Ensure 'Tamper Protection' is turned on.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
