Checks that the signature update interval is configured between 1-4 hours in all assigned Microsoft Defender Antivirus policies.

Infrequent signature updates reduce detection of the latest threats, leaving endpoints vulnerable to newly discovered malware and exploits.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **Signature Update Interval** to 1-4 hours

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
