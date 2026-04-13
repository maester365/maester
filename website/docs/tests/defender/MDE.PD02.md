---
title: MDE.PD02 - Exclusions should be in dedicated profiles
description: Manual review required. Verifies that antivirus exclusions are configured in dedicated profiles separate from baseline policies to reduce complexity.
slug: /tests/MDE.PD02
sidebar_class_name: hidden
---

# Exclusions should be in dedicated profiles

## Description

Manual review required. Verifies that antivirus exclusions are configured in dedicated profiles separate from baseline policies to reduce complexity. This is a manual review test.

## How to fix

1. Navigate to Microsoft Intune admin center (intune.microsoft.com).
2. Go to Devices > Configuration.
3. Verify that exclusions are in dedicated profiles (e.g., AV-EX-*) rather than mixed into baseline policies.

## Learn more
* [Microsoft Defender for Endpoint documentation](https://learn.microsoft.com/en-us/defender-endpoint/)
* [Microsoft Defender XDR portal](https://security.microsoft.com)
* [Microsoft Intune admin center](https://intune.microsoft.com)
