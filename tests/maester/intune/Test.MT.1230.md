Ensure at least one **assigned** iOS compliance policy requires a minimum operating system version.

Apple ships security fixes only in the current iOS release. A device left on an older major version keeps every browser engine and kernel vulnerability that release carried, including the ones Apple has published as actively exploited, and nothing in Intune makes the user install the update.

A **minimum OS version** in a compliance policy is how the tenant notices. A device below the version is marked non-compliant and can then be blocked by Conditional Access, which turns "please update" into a condition for access rather than a request.

By default this check requires only that a minimum version is **set at all**, because the version that is current ages out of any value fixed in a test. Set the `MinimumOsVersion` parameter to hold the tenant to a specific version, for example `18.0`.

A version Intune reports that cannot be compared with the required one is shown with its raw value and does not count towards a pass, rather than being guessed at in either direction. Intune accepts a single part value such as `18`, which is read as `18.0`.

#### Scope limitation

This check reads **Minimum OS version** from the compliance policy. It does not read **Maximum OS version**, and it does not look at the update policies that push an iOS release to a device. A minimum version marks a device non-compliant; it does not install anything.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
3. Select an existing iOS/iPadOS policy, or select **+ Create policy** with **Platform** set to **iOS/iPadOS**.
4. Under **Compliance settings** > **Device Properties** > **Operating System Version**, set **Minimum OS version** to the oldest release you support.
5. On the **Assignments** tab, assign the policy to your iOS device or user groups.
6. Select **Next** and then **Create** or **Save**.

Raise the value in stages. A device that cannot reach the version you set stays non-compliant until it is updated or replaced, so check the operating system versions in **Devices** > **All devices** first and give users notice.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - iOS/iPadOS compliance settings in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-ios-ipados-settings)
- [Apple Support - Apple security releases](https://support.apple.com/en-us/100100)

<!--- Results --->
%TestResult%
