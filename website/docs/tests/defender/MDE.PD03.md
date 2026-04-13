---
title: MDE.PD03 - Device profiles should be granular (Least Privilege)
description: Manual review required. Verifies that device profiles follow the principle of least privilege with granular device group targeting.
slug: /tests/MDE.PD03
sidebar_class_name: hidden
---

# Device profiles should be granular (Least Privilege)

## Description

Manual review required. Verifies that device profiles follow the principle of least privilege with granular device group targeting. This is a manual review test.

## How to fix

1. Navigate to Microsoft Intune admin center (intune.microsoft.com).
2. Go to Devices > Configuration.
3. Review policy assignments to ensure granular targeting by device type/role.
4. Avoid assigning policies to 'All devices' when specific targeting is possible.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Microsoft Defender XDR portal](https://security.microsoft.com)
* [Microsoft Intune admin center](https://intune.microsoft.com)
