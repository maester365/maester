Ensure macOS devices are restricted to trusted app download locations by Gatekeeper.

Gatekeeper decides which app download locations are permitted on macOS. Intune can address it two ways, and this check credits either:

- A **macOS compliance policy** evaluates the device's current Gatekeeper state and marks the device non-compliant if it is looser than required, which feeds Conditional Access.
- A **macOS configuration policy** pushes the `com.apple.systempolicy.control` payload, enforcing the setting on the device rather than merely observing it. The macOS endpoint protection template is deprecated, so this is authored in the settings catalog under **System Policy Control**.

The compliance policy exposes it as **Allow apps downloaded from these locations**, with three meaningful states:

- **Mac App Store** - only App Store apps may run. The most restrictive option.
- **Mac App Store and identified developers** - App Store apps plus apps signed by a developer whose identity Apple has verified and notarized. The practical baseline for most organizations.
- **Anywhere** - any app from any source may run, including unsigned binaries. This is the least secure setting, and Apple removed it from the macOS user interface for good reason.

When the setting is left as **Not configured**, Gatekeeper has no effect on the compliance verdict at all, so a Mac whose user has allowed apps from anywhere is still reported as compliant.

Unrestricted app sources are a direct initial-access path. Unsigned or ad-hoc signed binaries delivered by phishing or a drive-by download execute without Gatekeeper objection, which is how macOS infostealers such as Atomic Stealer are routinely installed. Restricting the allowed source breaks that chain at execution.

On the configuration side, two payload keys matter: `enableassessment` controls whether Gatekeeper is active at all, and `allowidentifieddevelopers` decides whether Developer ID signed apps are permitted alongside App Store apps.

This test passes if at least one **assigned** policy of either kind restricts app sources. A compliance policy set to **Anywhere** or left unconfigured does not count, and neither does a configuration policy that disables Gatekeeper assessment. Unassigned policies are reported but never applied or evaluated, so they do not count either.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
3. Select an existing macOS policy, or select **+ Create policy** with **Platform** set to **macOS**.
4. Under **Compliance settings** > **System Security** > **Gatekeeper**, set **Allow apps downloaded from these locations** to **Mac App Store and identified developers** (or **Mac App Store** if your app estate allows it).
5. On the **Assignments** tab, assign the policy to your macOS device or user groups.
6. Select **Next** and then **Create** or **Save**.

To enforce the setting rather than only report on it, also create a configuration policy:

1. Go to **Devices** > **Manage devices** > **[Configuration](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/configuration)** > **Create** > **New policy**.
2. Set **Platform** to **macOS** and **Profile type** to **Settings catalog**.
3. Add the **System Policy Control** category, then enable **Enable Assessment** and set **Allow Identified Developers** as your app estate requires.
4. Assign the policy to your macOS groups.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Device compliance settings for macOS in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-macos-settings)
- [Microsoft Learn - Levels of protection and configuration in Intune](https://learn.microsoft.com/intune/fundamentals/protection-configuration-levels)
- [Apple Support - Safely open apps on your Mac](https://support.apple.com/en-us/102445)

<!--- Results --->
%TestResult%
