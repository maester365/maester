Checks that local admin merge is disabled to block local exclusions in all assigned Microsoft Defender Antivirus policies.

Local admin policy override allows privilege escalation to bypass security controls, enabling local administrators to add exclusions that weaken endpoint protection.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Enable **Disable Local Admin Merge** to prevent local overrides

#### Related links

- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
