---
title: MDE.PD04 - Staging buckets should be implemented (Pilot to Prod)
description: Manual review required. Verifies that staging deployment buckets are implemented with pilot and production groups for safe policy rollout.
slug: /tests/MDE.PD04
sidebar_class_name: hidden
---

# Staging buckets should be implemented (Pilot to Prod)

## Description

Manual review required. Verifies that staging deployment buckets are implemented with pilot and production groups for safe policy rollout. This is a manual review test.

## How to fix

1. Navigate to Microsoft Intune admin center (intune.microsoft.com).
2. Go to Devices > Groups.
3. Verify pilot groups exist (e.g., DG-CL-GEN-PILOT).
4. Ensure policies are first tested on pilot groups before production deployment.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Microsoft Defender XDR portal](https://security.microsoft.com)
* [Microsoft Intune admin center](https://intune.microsoft.com)
