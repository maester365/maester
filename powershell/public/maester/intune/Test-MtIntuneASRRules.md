Ensure at least one Intune Attack Surface Reduction (ASR) policy has rules configured in **Block** or **Audit** mode.

ASR rules reduce the attack surface of applications by preventing behaviors commonly abused by malware and threat actors. These rules target specific techniques such as:

- **Office macros** spawning child processes or injecting code into other processes
- **Credential theft** from LSASS (Local Security Authority Subsystem Service)
- **Script-based attacks** using obfuscated JavaScript, VBScript, or PowerShell
- **Email-borne threats** executing content from Outlook or webmail
- **Ransomware** advanced protection heuristics
- **USB-based attacks** running untrusted unsigned processes
- **Persistence** through WMI event subscriptions

Each ASR rule can operate in one of three modes:

- **Block**: Actively prevents the behavior (recommended for production after testing)
- **Audit**: Logs the event without blocking (recommended for initial rollout)
- **Disabled**: Rule is not active

The test passes if at least one ASR policy has at least one rule configured in **Block** or **Audit** mode. Policies with all rules in **Audit** mode will trigger an informational note recommending a transition to **Block** mode.

#### Remediation action:

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
- [Microsoft Learn - ASR rules reference](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-reference)
- [Microsoft Learn - Enable ASR rules in Intune](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/enable-attack-surface-reduction)
- [Microsoft Learn - ASR rules deployment guide](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-deployment)

<!--- Results --->
%TestResult%
