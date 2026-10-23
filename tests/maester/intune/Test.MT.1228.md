Ensure at least one **assigned** iOS compliance policy blocks jailbroken devices.

A jailbroken iPhone or iPad has had the chain of platform protections that iOS is trusted for removed: code signing enforcement, the app sandbox, and the protections around the keychain. Apps from outside the App Store run unsigned, one app can read another app's data, and the credentials and refresh tokens that iOS stores for Microsoft Authenticator, Outlook and Teams become reachable by anything running on the device.

**Intune cannot prevent a device from being jailbroken.** What it can do is evaluate the jailbreak signal as a compliance condition, so that the device is marked non-compliant and can then be blocked by Conditional Access.

That distinction is the point of this check. Without the rule, Intune reports a jailbroken device as healthy, and the device keeps its access to corporate resources with exactly the platform guarantees that justified granting that access gone.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
3. Select an existing iOS/iPadOS policy, or select **+ Create policy** with **Platform** set to **iOS/iPadOS**.
4. Under **Compliance settings** > **Device Health**, set **Jailbroken devices** to **Block**.
5. On the **Assignments** tab, assign the policy to your iOS device or user groups.
6. Select **Next** and then **Create** or **Save**.

Consider also configuring **Actions for noncompliance** so that users are notified before the device is marked non-compliant.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - iOS/iPadOS compliance settings in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-ios-ipados-settings)
- [Microsoft Learn - Levels of protection and configuration in Intune](https://learn.microsoft.com/intune/fundamentals/protection-configuration-levels)

<!--- Results --->
%TestResult%
