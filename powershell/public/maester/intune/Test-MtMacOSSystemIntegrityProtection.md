Ensure at least one **assigned** macOS compliance policy requires System Integrity Protection.

System Integrity Protection (SIP) is a macOS kernel-level protection that prevents even the root user from modifying protected system files, directories and processes, or attaching a debugger to system binaries. It is enabled by default on macOS.

**SIP cannot be enforced by an MDM.** It is toggled from macOS Recovery on the device itself. What Intune can do is *require* it as a compliance condition, so that a Mac with SIP disabled is marked non-compliant and can then be blocked by Conditional Access.

That distinction is the point of this check. Disabling SIP takes a deliberate, physically present action, and it is how unsigned kernel extensions get loaded, how endpoint security agents such as Microsoft Defender for Endpoint are tampered with, and how persistence is established in protected system locations. Without a compliance rule consuming that signal, Intune reports such a device as healthy and it keeps its access to corporate resources.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
3. Select an existing macOS policy, or select **+ Create policy** with **Platform** set to **macOS**.
4. Under **Compliance settings** > **Device Health**, set **Require a system integrity protection** to **Require**.
5. On the **Assignments** tab, assign the policy to your macOS device or user groups.
6. Select **Next** and then **Create** or **Save**.

Consider also configuring **Actions for noncompliance** so that users are notified before the device is marked non-compliant.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Device compliance settings for macOS in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-macos-settings)
- [Microsoft Learn - Levels of protection and configuration in Intune](https://learn.microsoft.com/intune/fundamentals/protection-configuration-levels)
- [Apple Support - About System Integrity Protection](https://support.apple.com/en-us/102149)

<!--- Results --->
%TestResult%
