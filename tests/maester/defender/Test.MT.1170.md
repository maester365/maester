Verify that catch-up quick scan is disabled to avoid additional system load.

Enabled catchup scans may cause performance issues on mobile devices.

#### Remediation action:

1. Open [Microsoft Endpoint Manager](https://endpoint.microsoft.com) > **Endpoint Security** > **Antivirus**
2. Edit the relevant Microsoft Defender Antivirus policy
3. Enable **Disable Catchup Quick Scan** to avoid additional system load

If your antivirus settings are split across several policies, this setting only needs to be set in one of them, as long as that policy is assigned to every device that needs it. No other assigned policy should set a different value: Intune does not merge this setting, so a device that receives both values may end up with either one, or none.

#### Related links

- [Policy merge and conflicts for Antivirus policy settings](https://learn.microsoft.com/intune/device-configuration/endpoint-security/antivirus#policy-merge-for-settings)
- [Configure Microsoft Defender Antivirus](https://learn.microsoft.com/microsoft-365/security/defender-endpoint/configure-microsoft-defender-antivirus-features)
- [Microsoft Endpoint Manager](https://endpoint.microsoft.com)

<!--- Results --->
%TestResult%
