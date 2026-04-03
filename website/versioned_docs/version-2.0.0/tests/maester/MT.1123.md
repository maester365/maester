---
title: MT.1123 - Ensure BitLocker full disk encryption is configured via Intune
description: Checks if at least one Intune Endpoint Protection profile enforces BitLocker full disk encryption for OS and fixed data drives.
slug: /tests/MT.1123
sidebar_class_name: hidden
---

# Ensure BitLocker full disk encryption is configured via Intune

## Description

BitLocker Drive Encryption protects data on Windows devices, but the **encryption type** setting is critical:

- **Full disk encryption** — encrypts the entire drive including free space. This is the secure option.
- **Used space only encryption** — only encrypts sectors currently holding data. Previously deleted files that existed before encryption was enabled remain as raw data in unencrypted free space and **can be recovered using data recovery software** (e.g., Recuva, PhotoRec, forensic imaging tools). This happens because NTFS marks deleted sectors as "free" but does not zero them — the original bytes persist on disk until overwritten.

This test checks that at least one Windows 10/11 Endpoint Protection configuration profile exists in Intune with BitLocker settings configured. It inspects `bitLockerEncryptDevice`, `bitLockerSystemDrivePolicy`, and `bitLockerFixedDrivePolicy` via the Graph API.

> **Note:** The Endpoint Protection Graph API does not expose the "encryption type" (full disk vs used space only) setting. That is controlled via the BitLocker CSP (`SystemDrivesEncryptionType` / `FixedDrivesEncryptionType`), configured through Intune **Settings Catalog** or **Disk Encryption** profiles. When BitLocker is detected, the test outputs a warning to verify full disk encryption is enforced.

## How to fix

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Click **Devices** > **Manage devices** > **Configuration**.
3. Click **+ Create** > **New policy**.
4. Set **Platform** to **Windows 10 and later**.
5. Set **Profile type** to **Templates** > **Endpoint protection**.
6. Under **Windows Encryption**, configure:
   - **Encrypt devices**: **Require**
   - **BitLocker OS drive settings**: Enable, set **Encryption method** to **XTS-AES 256-bit**
   - **BitLocker fixed drive settings**: Enable, set **Encryption method** to **XTS-AES 256-bit**
7. **Additionally**, create a **Settings Catalog** or **Disk Encryption** profile to set:
   - **Enforce drive encryption type on operating system drives**: **Full encryption**
   - **Enforce drive encryption type on fixed data drives**: **Full encryption**
8. Assign both profiles to your device groups.

## Learn more

- [Microsoft Intune - Device Configuration](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration)
- [Microsoft Learn - Encrypt devices with BitLocker in Intune](https://learn.microsoft.com/en-us/mem/intune/protect/encrypt-devices)
- [Microsoft Learn - BitLocker settings reference](https://learn.microsoft.com/en-us/mem/intune/protect/endpoint-protection-windows-10#windows-settings)
