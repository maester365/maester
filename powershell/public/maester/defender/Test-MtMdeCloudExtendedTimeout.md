Checks that the cloud extended timeout is configured between 30-50 seconds in all assigned Microsoft Defender Antivirus policies.

Insufficient cloud timeout may prevent thorough analysis of suspicious files, allowing potentially malicious content to bypass cloud-based detection.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **Cloud Extended Timeout** to 30-50 seconds

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
