Ensure the share of **non-compliant** Intune managed devices stays below a threshold you set.

Maester's other Intune checks look at how device compliance policies are *configured*. This check looks at the *outcome* Intune reports: of the devices Intune has actually evaluated, how many are non-compliant. A policy can be configured perfectly and still leave a fleet full of non-compliant devices, because devices fall out of compliance for reasons a policy cannot fix: an out-of-date OS, disk encryption switched off, a missing security agent, or a device that stopped checking in.

A device's compliance state is one of `compliant`, `noncompliant`, `conflict`, `error`, `inGracePeriod`, `unknown` or `configManager`. This test counts a device as non-compliant when it is `noncompliant`, in `conflict`, in `error`, or in the grace period (`inGracePeriod` is non-compliant but still has access to corporate resources). It leaves `unknown` and `configManager` devices out of the calculation: an `unknown` device has not reported a verdict, and a `configManager` device is evaluated by Configuration Manager, not Intune.

The test passes when the non-compliant share of evaluated devices is at or below the threshold, which defaults to **5%**. Set your own in `maester-config.json` under `TestSettings` > `Parameters` with `MaxNonCompliantPercentage`.

A tenant with no managed devices, or where no device has reported a verdict yet, is **skipped as not applicable**. A share of zero over zero devices is not a pass.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Monitor** > **[Noncompliant devices](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/complianceReport)** to see which devices are non-compliant and which setting each one fails.
3. Work through the devices: update the operating system, turn on the required protection, or re-enroll devices that stopped checking in.
4. Configure **Actions for noncompliance** on your compliance policies so users are notified and given time to remediate before a device is blocked.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Monitor device compliance](https://learn.microsoft.com/intune/intune-service/protect/compliance-policy-monitor)
- [Microsoft Learn - Device compliance states](https://learn.microsoft.com/graph/api/resources/intune-devices-compliancestate)

<!--- Results --->
%TestResult%
