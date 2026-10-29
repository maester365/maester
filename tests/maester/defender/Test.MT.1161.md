Checks that the cloud block level is set to High or higher in the assigned Microsoft Defender Antivirus policies.

A low cloud block level reduces proactive threat blocking capabilities, allowing more suspicious files to execute without cloud-based analysis.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Set **Cloud Block Level** to High, High Plus, or Zero Tolerance

If your antivirus settings are split across several policies, this setting only needs to be set in one of them, as long as that policy is assigned to every device that needs it. No other assigned policy should set a different value: Intune does not merge this setting, so a device that receives both values may end up with either one, or none.

#### Related links

- [Policy merge and conflicts for Antivirus policy settings](https://learn.microsoft.com/intune/device-configuration/endpoint-security/antivirus#policy-merge-for-settings)
- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
