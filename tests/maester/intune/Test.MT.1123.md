Ensure at least one Intune policy enforces BitLocker **full encryption** on operating system drives.

BitLocker offers two encryption types, and the difference matters:

- **Full encryption** encrypts the entire drive, including free space.
- **Used Space Only encryption** encrypts only the sectors that currently hold data.

Used Space Only is the risk. When NTFS deletes a file it marks those sectors as free without zeroing them, so the original bytes stay on disk until something overwrites them. Enable BitLocker with Used Space Only on a drive that already held data and everything deleted beforehand remains recoverable with ordinary tools such as Recuva or PhotoRec, or with forensic imaging. Only Full encryption protects the whole drive surface.

BitLocker can be configured from either **Endpoint security** > **Disk encryption** or **Devices** > **Configuration** > **Settings catalog**. Both write the same settings, and both satisfy this check.

#### Remediation action

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Disk encryption**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **BitLocker**.
5. Enter a policy name (e.g., "BitLocker - Full Disk Encryption").
6. Configure the following settings:
   - **Require Device Encryption**: **Enabled**
   - **Allow Warning For Other Disk Encryption**: **Disabled** (enables silent encryption)
   - **Allow Standard User Encryption**: **Enabled**
   - **Enforce drive encryption type on operating system drives**: **Enabled**, set to **Full encryption**
   - **Enforce drive encryption type on fixed data drives**: **Enabled**, set to **Full encryption**
   - **Choose drive encryption method and cipher strength**: **Enabled**
     - OS drives: **XTS-AES 256-bit**
     - Fixed data drives: **XTS-AES 256-bit**
     - Removable data drives: **AES-CBC 256-bit**
   - **Require additional authentication at startup**: **Enabled**, with **Require TPM**
   - **Choose how BitLocker-protected OS drives can be recovered**: **Enabled**, with backup to Entra ID
7. Assign the policy to your device groups and click **Create**.

#### Related links

- [Microsoft Intune - Endpoint Security Disk Encryption](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/diskEncryption)
- [Microsoft Learn - Encrypt devices with BitLocker in Intune](https://learn.microsoft.com/mem/intune/protect/encrypt-devices)
- [Microsoft Learn - BitLocker CSP reference](https://learn.microsoft.com/windows/client-management/mdm/bitlocker-csp)
- [CIS Benchmark - Ensure BitLocker is enabled on all Windows devices](https://www.cisecurity.org/benchmark/microsoft_intune_for_windows)

<!--- Results --->
%TestResult%
