Ensure at least one Intune LAPS policy is configured to **back up local admin passwords to Microsoft Entra ID**.

Windows LAPS (Local Administrator Password Solution) automatically rotates and backs up local administrator passwords on managed devices. Without LAPS, local admin accounts often share the same password across all devices — if one device is compromised, an attacker can move laterally to every other device using the same credentials.

Key settings this test evaluates:

- **Backup Directory**: Must be set to **Azure AD only** (Entra ID) to store passwords in the cloud where they can be retrieved by authorized admins.
- **Password Complexity**: Must be `Large + small + numbers + special` (`_4`) or improved (`_8`).
- **Password Length**: Must be **>= 14** characters.
- **Post-Authentication Actions**: Must be set to a defined action (`_1` reset password / `_3` reset password + logoff / `_5` reset password + reboot / `_11` reset password + logoff + terminate processes) so the password rotates after use.
- **Automatic Account Management**: Whether LAPS auto-manages the local admin account lifecycle (informational).

The test passes if **at least one LAPS policy** meets **all** of the criteria above (Entra backup AND complexity >= `_4` AND length >= 14 AND a defined post-auth action). A policy that only sets Backup Directory is no longer sufficient.

#### Remediation action:

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Account protection**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **Local admin password solution (Windows LAPS)**.
5. Enter a policy name (e.g., "LAPS - Entra ID Backup").
6. Configure the following settings:
   - **Backup Directory**: **Azure AD only**
   - **Password Complexity**: **Large letters + small letters + numbers + special characters**
   - **Password Length**: **21** (or at least 14)
   - **Post-Authentication Actions**: **Reset password and logoff**
   - **Post-Authentication Reset Delay**: **1 hour**
   - **Administrator Account Name**: Leave default or specify custom account
7. Assign the policy to your device groups and click **Create**.

#### Related links

- [Microsoft Intune - Endpoint Security Account Protection](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/accountprotection)
- [Microsoft Learn - Windows LAPS with Microsoft Intune](https://learn.microsoft.com/en-us/mem/intune/protect/windows-laps-overview)
- [Microsoft Learn - Windows LAPS CSP reference](https://learn.microsoft.com/en-us/windows/client-management/mdm/laps-csp)
- [CIS Benchmark - Ensure LAPS is configured for local admin accounts](https://www.cisecurity.org/benchmark/microsoft_intune_for_windows)

<!--- Results --->
%TestResult%
