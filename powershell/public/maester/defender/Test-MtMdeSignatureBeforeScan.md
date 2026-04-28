Checks that signature checking before scan is enabled for zero-day protection in all assigned Microsoft Defender Antivirus policies.

Scans with outdated signatures may miss recent threats and zero-day attacks, leaving endpoints exposed to newly discovered vulnerabilities.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Enable **Check for Signatures Before Running Scan**

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
