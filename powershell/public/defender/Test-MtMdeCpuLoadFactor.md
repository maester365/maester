Checks that the average CPU load factor is configured between 20-30% in all assigned Microsoft Defender Antivirus policies.

Inappropriate CPU load settings may impact system performance or reduce scan effectiveness, leaving endpoints vulnerable to threats.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **Average CPU Load Factor** to 20-30%

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
