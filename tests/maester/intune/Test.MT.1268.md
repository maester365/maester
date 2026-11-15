Ensure devices **assigned a security baseline** comply with it.

A security baseline is Microsoft's recommended set of hardening settings for a product (Windows, Microsoft Edge, Microsoft Defender for Endpoint and others). Assigning one is only half the job: a device can be assigned a baseline and still deviate from it, because a setting conflicts with another policy, because the device has not applied it, or because enforcement errored. Intune reports that outcome per baseline, and this check surfaces it.

This test runs **once per assigned security baseline**, of either kind.

**Legacy baselines** (the security baseline templates) report a device-state summary. The baseline **passes** when every device Intune has evaluated against it is secure, and **fails** when any device is not secure, in conflict, or in error. A baseline that is assigned but has no evaluated device yet (every device still unknown or not applicable) is **skipped as not applicable**.

**Settings catalog baselines** — the kind the admin center creates today — are listed with their assignment count and **skipped as not applicable** rather than judged. Intune publishes no per-device compliance summary for them through a documented API: the `configurationPolicies` resource has no `deviceStatuses` navigation, and the one route that carries the state, the `DeviceStatusesByConfigurationProfile` export, documents its column names but not the meaning of their values. Reporting the baseline and saying the number is unavailable is honest; deciding a tenant's posture on an undocumented encoding is not, and passing it silently would be worse than both. To see their state, open the baseline in the admin center.

A tenant with no assigned baselines of either kind is skipped: there is nothing to report on, and that is never a pass.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Endpoint security** > **[Security baselines](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/securityBaselines)** and open the baseline named in the result.
3. On the baseline's **Overview**, review the per-device and per-setting state to see which devices are not secure or in conflict and which setting each one deviates on.
4. Resolve conflicts (a second policy setting the same value differently), then remediate or re-sync the affected devices.

#### Related links

- [Microsoft Intune admin center - Security baselines](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/securityBaselines)
- [Microsoft Learn - Use security baselines to configure Windows devices in Intune](https://learn.microsoft.com/intune/intune-service/protect/security-baselines)
- [Microsoft Learn - Monitor security baselines and profiles](https://learn.microsoft.com/intune/intune-service/protect/security-baselines-monitor)
- [Microsoft Learn - Intune reports available using Graph APIs](https://learn.microsoft.com/intune/device-management/reports/ref-graph-available-reports#devicestatusesbyconfigurationprofile)

<!--- Results --->
%TestResult%
