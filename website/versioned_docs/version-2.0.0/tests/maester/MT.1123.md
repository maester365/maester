---
title: MT.1123 - Ensure BitLocker full disk encryption is configured via Intune
description: Checks if at least one Intune Endpoint Security Disk encryption policy enforces BitLocker full disk encryption for OS drives.
slug: /tests/MT.1123
sidebar_class_name: hidden
---

# Ensure BitLocker full disk encryption is configured via Intune

## Description

BitLocker Drive Encryption protects data on Windows devices, but the **encryption type** setting is critical:

- **Full disk encryption** — encrypts the entire drive including free space. This is the secure option.
- **Used space only encryption** — only encrypts sectors currently holding data. Previously deleted files that existed before encryption was enabled remain as raw data in unencrypted free space and **can be recovered using data recovery software** (e.g., Recuva, PhotoRec, forensic imaging tools). This happens because NTFS marks deleted sectors as "free" but does not zero them — the original bytes persist on disk until overwritten.

This test queries the `configurationPolicies` Graph API (the same API used by the Intune admin center's **Endpoint Security > Disk Encryption** blade). It reads the BitLocker CSP settings — specifically `SystemDrivesEncryptionType` and `FixedDrivesEncryptionType` — to verify that at least one Disk Encryption policy enforces **Full encryption** for OS drives. It also reports `RequireDeviceEncryption` status and cipher strength (`EncryptionMethodByDriveType`) for each policy.

The test **passes** only if at least one BitLocker Disk Encryption policy has the OS drive encryption type set to "Full encryption". It **fails** if no policies exist, or if all policies use "Used space only" or "Allow user to choose".

## How to fix

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Disk encryption**.
3. Click **Create Policy**.
4. Set **Platform** to **Windows 10 and later**.
5. Set **Profile** to **BitLocker**.
6. Under the BitLocker settings, configure:
   - **Enforce drive encryption type on operating system drives**: **Full encryption** (`SystemDrivesEncryptionType`)
   - **Enforce drive encryption type on fixed data drives**: **Full encryption** (`FixedDrivesEncryptionType`)
   - **Require Device Encryption**: **Enabled**
   - **Choose drive encryption method and cipher strength**: **Enabled**
     - OS drives: **XTS-AES 256-bit**
     - Fixed data drives: **XTS-AES 256-bit**
     - Removable data drives: **AES-CBC 256-bit**
7. Assign the policy to your device groups.

## Learn more

- [Microsoft Intune - Endpoint Security Disk Encryption](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/diskEncryption)
- [Microsoft Learn - Encrypt devices with BitLocker in Intune](https://learn.microsoft.com/en-us/mem/intune/protect/encrypt-devices)
- [Microsoft Learn - BitLocker CSP reference](https://learn.microsoft.com/en-us/windows/client-management/mdm/bitlocker-csp)
