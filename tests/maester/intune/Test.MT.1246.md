Ensure at least one **assigned** Android app protection policy encrypts organization data.

App protection encryption puts the organization's data in the managed apps under a key the Intune App SDK controls, separately from whatever the user has done with the device. On an unenrolled Android phone the organization cannot verify how the device encrypts storage, and the fleet spans a decade of manufacturers and patch levels.

**Android exposes this as two settings that can contradict each other:**

- **Encrypt org data** (`encryptAppData`) requires the app data to be encrypted.
- `disableAppEncryptionIfDeviceEncryptionIsEnabled` waives that requirement whenever the device reports its own encryption as enabled.

A policy can therefore show encryption as required and encrypt nothing, because the waiver hands the guarantee back to the device the organization does not manage. This test reads both, and reports the contradictory combination as a note even when another policy passes.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **Android** policy, or select **+ Create policy** and choose **Android**.
4. Under **Data protection** > **Encryption**, set **Encrypt org data** to **Require**.
5. Leave the option that disables app encryption when the device is encrypted turned **off**, so the policy keeps its own key on unmanaged devices.
6. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
7. Select **Next** and then **Create** or **Save**.

#### Related links

- [Microsoft Learn - Android app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-android)
- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - App protection policies overview](https://learn.microsoft.com/intune/app-management/protection/overview)

<!--- Results --->
%TestResult%
