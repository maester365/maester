---
title: MT.1168 - Cleaned Malware should be retained for at least 30 days
description: Verifies that quarantined malware samples are retained for at least 30 days for forensic analysis.
slug: /tests/MT.1168
sidebar_class_name: hidden
---

# Cleaned Malware should be retained for at least 30 days

## Description

Verifies that quarantined malware samples are retained for at least 30 days for forensic analysis.

## How to fix

Navigate to Intune > Devices > Configuration > Settings Catalog > Microsoft Defender Antivirus. Set 'Days To Retain Cleaned Malware' to 30 or higher.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Intune Settings Catalog - Configuration profiles](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configurationProfiles)
