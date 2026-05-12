---
title: MT.1177 - Ensure LAPS Configuration Policy is properly set
description: Checks Intune Endpoint Security Account Protection policies for Windows LAPS profiles that back up local administrator passwords to Microsoft Entra ID.
slug: /tests/MT.1177
sidebar_class_name: hidden
---

# Ensure LAPS Configuration Policy is properly set

## Description

Checks Intune Endpoint Security Account Protection policies for Windows Local Administrator Password Solution (LAPS) profiles that back up local administrator passwords to Microsoft Entra ID.

Windows LAPS automatically rotates and backs up local administrator passwords, preventing lateral movement attacks that exploit shared or stale local admin credentials.

Key settings evaluated:

- **Backup Directory**: Must be set to `Azure AD only` (`_1`) so passwords are stored in Entra ID and can be retrieved centrally.
- **Password Complexity**: Must be `Large + small + numbers + special` (`_4`) or improved (`_8`).
- **Password Length**: Must be **>= 14** characters.
- **Post-Authentication Actions**: Must be set to a defined action (`_1`/`_3`/`_5`/`_11`) so the password rotates after use.
- **Automatic Account Management**: Whether LAPS auto-manages the local admin account (informational).

The test passes if **at least one LAPS policy** meets **all** of the criteria above (Entra backup AND complexity >= `_4` AND length >= 14 AND a defined post-auth action).

## How to fix

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Account protection**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **Local admin password solution (Windows LAPS)**.
5. Configure:
   - **Backup Directory**: **Azure AD only**
   - **Password Complexity**: `Large + small + numbers + special` or improved
   - **Password Length**: **14** characters or more
   - **Post-Authentication Actions**: **Reset password** (or stronger)
   - **Post-Authentication Reset Delay**: 12 hours or fewer
6. Assign the policy to your Windows device groups and click **Create**.

## Learn more

- [Windows LAPS overview](https://learn.microsoft.com/mem/intune/protect/windows-laps-overview)
- [Windows LAPS policy CSP](https://learn.microsoft.com/windows/client-management/mdm/laps-csp)
- [Account protection policies in Intune](https://learn.microsoft.com/mem/intune/protect/endpoint-security-account-protection-policy)
