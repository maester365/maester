---
title: MDE.AV25 - Remediation Action should be set to Quarantine
description: Manual review required. Verifies that the default remediation action for detected threats is set to quarantine for all severity levels. This requires reviewing Intune policy settings for threat severity default actions.
slug: /tests/MDE.AV25
sidebar_class_name: hidden
---

# Remediation Action should be set to Quarantine

## Description

Manual review required. Verifies that the default remediation action for detected threats is set to quarantine for all severity levels. This requires reviewing Intune policy settings for threat severity default actions.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus > Threats. Review and ensure threat severity default actions are set to 'Quarantine' for all threat levels.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
