Ensure at least one Intune **App Control for Business** (formerly Windows Defender Application Control / WDAC) policy is configured.

App Control for Business restricts which applications and drivers are allowed to run on Windows devices using code integrity policies. This is one of the most effective defenses against malware, ransomware, and unauthorized software because it blocks untrusted executables from running at all — even if they bypass antivirus detection.

Key settings this test evaluates:

- **Build Options**: Whether the policy uses built-in controls or a custom uploaded policy
- **Audit Mode**: Whether the policy is in audit mode (logging only) or enforce mode (blocking)
- **Managed Installer**: Whether apps deployed via Intune/SCCM are automatically trusted
- **Intelligent Security Graph (ISG) Reputation**: Whether apps with good reputation scores are trusted

The test passes if at least one App Control for Business policy exists with built-in controls or a custom policy configured. Policies in **Audit mode** will trigger an informational note recommending a transition to **Enforce mode** after validation.

#### Remediation action:

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Application control**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **App Control for Business**.
5. Enter a policy name (e.g., "App Control - Audit Mode").
6. Configure the following settings:
   - **App Control for Business**: Select **Built-in controls**
   - **Audit mode**: **Enabled** (start in audit mode to identify blocked apps)
   - **Trust apps from managed installer**: **Enabled** (trusts Intune-deployed apps)
   - **Trust apps with good reputation**: **Disabled** (optional — ISG adds convenience but reduces strictness)
7. Assign the policy to a test device group first.
8. Monitor blocked/audited apps in **Microsoft Defender for Endpoint** > **Reports** > **Application control**.
9. After validating that legitimate apps are not being blocked, transition to **Enforce mode**.

#### Related links

- [Microsoft Intune - Application Control](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/asr)
- [Microsoft Learn - App Control for Business in Intune](https://learn.microsoft.com/en-us/mem/intune/protect/endpoint-security-app-control-policy)
- [Microsoft Learn - Application Control for Windows](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/appcontrol)
- [Microsoft Learn - Managed Installer and ISG options](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/configure-appcontrol-managed-installer)

<!--- Results --->
%TestResult%
