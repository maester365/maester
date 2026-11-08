Ensure devices **assigned a security baseline** comply with it.

A security baseline is Microsoft's recommended set of hardening settings for a product (Windows, Microsoft Edge, Microsoft Defender for Endpoint and others). Assigning one is only half the job: a device can be assigned a baseline and still deviate from it, because a setting conflicts with another policy, because the device has not applied it, or because enforcement errored. Intune reports that outcome per baseline, and this check surfaces it.

This test runs **once per assigned security baseline** — a baseline that reports against at least one device. For each, Intune summarises its devices as secure, not secure, in conflict, in error, unknown or not applicable. The baseline **passes** when every device Intune has evaluated against it is secure, and **fails** when any device is not secure, in conflict, or in error.

A baseline that is assigned but has no evaluated device yet (every device still unknown or not applicable) is **skipped as not applicable**. A tenant with no assigned baselines is skipped too: there is nothing to report on, and that is never a pass.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **[Security baselines](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/securityBaselines)** and open the baseline named in the result.
3. On the baseline's **Overview**, review the per-device and per-setting state to see which devices are not secure or in conflict and which setting each one deviates on.
4. Resolve conflicts (a second policy setting the same value differently), then remediate or re-sync the affected devices.

#### Related links

- [Microsoft Intune admin center - Security baselines](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/securityBaselines)
- [Microsoft Learn - Use security baselines to configure Windows devices in Intune](https://learn.microsoft.com/intune/intune-service/protect/security-baselines)
- [Microsoft Learn - Monitor security baselines and profiles](https://learn.microsoft.com/intune/intune-service/protect/security-baselines-monitor)

<!--- Results --->
%TestResult%
