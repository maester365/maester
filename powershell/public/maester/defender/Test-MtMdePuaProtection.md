Checks that PUA (Potentially Unwanted Applications) protection is enabled in all assigned Microsoft Defender Antivirus policies.

Disabled PUA protection allows Shadow IT and potentially unwanted applications to be installed on managed devices, increasing the attack surface.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **PUA Protection** to On (Block mode)

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
