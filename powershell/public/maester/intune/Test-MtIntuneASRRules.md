Ensure every rule in the Microsoft Defender ASR Standard Protection baseline is configured in **Block** or **Audit** mode.

Attack surface reduction rules block the behaviors malware depends on but legitimate software rarely needs: Office macros spawning child processes, credential theft from LSASS, obfuscated scripts, executable content arriving by email, untrusted processes running from USB media, and persistence through WMI event subscriptions.

Each rule runs in one of four modes:

- **Block** prevents the behavior. This is the goal for production.
- **Audit** logs it without blocking. Start here to measure impact.
- **Warn** prompts the user, who can choose to continue anyway.
- **Disabled** turns the rule off.

This check passes when all three Standard Protection baseline rules are in **Block** or **Audit** somewhere in the tenant. Modes are pooled across policies, so rules split over several policies still count:

1. Block abuse of exploited vulnerable signed drivers
2. Block credential stealing from LSASS
3. Block persistence through WMI event subscription

Microsoft publishes these as the [minimum set for an initial ASR deployment](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-deployment-implement). Any other ASR rules found are listed for visibility but do not affect the result. **Warn** does not satisfy the baseline, and baseline rules left in **Audit** produce a note recommending a move to **Block**.

ASR rules can be configured from either **Endpoint security** > **Attack surface reduction** or **Devices** > **Configuration** > **Settings catalog** (under **Defender**). Both write the same settings, and both satisfy this check.

#### Remediation action

1. Navigate to [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **Attack surface reduction**.
3. Click **+ Create policy**.
4. Set **Platform** to **Windows 10 and later** and **Profile** to **Attack Surface Reduction Rules**.
5. Enter a policy name (e.g., "ASR Rules - Audit Mode").
6. Configure individual ASR rules — start with **Audit** mode for all rules:
   - Block abuse of exploited vulnerable signed drivers
   - Block Adobe Reader from creating child processes
   - Block all Office applications from creating child processes
   - Block credential stealing from Windows LSASS
   - Block executable content from email client and webmail
   - Block executable files unless they meet prevalence, age, or trusted list criteria
   - Block execution of potentially obfuscated scripts
   - Block JavaScript or VBScript from launching downloaded executable content
   - Block Office applications from creating executable content
   - Block Office applications from injecting code into other processes
   - Block Office communication app from creating child processes
   - Block persistence through WMI event subscription
   - Block process creations originating from PSExec and WMI commands
   - Block untrusted and unsigned processes that run from USB
   - Block Win32 API calls from Office macros
   - Use advanced protection against ransomware
7. Assign the policy to your device groups and click **Create**.
8. Monitor audit events in **Microsoft Defender for Endpoint** > **Reports** > **Attack surface reduction rules** for 2–4 weeks before transitioning rules to **Block** mode.

#### Related links

- [Microsoft Intune - Attack Surface Reduction](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/asr)
- [Microsoft Learn - ASR rules reference](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-reference)
- [Microsoft Learn - Enable ASR rules in Intune](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/enable-attack-surface-reduction)
- [Microsoft Learn - ASR rules deployment guide](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-deployment)

<!--- Results --->
%TestResult%
