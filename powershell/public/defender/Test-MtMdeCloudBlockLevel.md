Checks that the cloud block level is set to High or higher in all assigned Microsoft Defender Antivirus policies.

A low cloud block level reduces proactive threat blocking capabilities, allowing more suspicious files to execute without cloud-based analysis.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **Cloud Block Level** to High, High Plus, or Zero Tolerance

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
