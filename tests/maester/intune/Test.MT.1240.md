Ensure at least one **assigned** iOS app protection policy encrypts organization data.

App protection encryption puts the organization's data in the managed apps under a key the Intune App SDK controls, separately from whatever the user has done with the device. On an unenrolled phone the organization cannot require a device passcode, and iOS data protection is only as strong as the passcode behind it: a device with no passcode gives little protection to files at rest.

The setting is a choice of **when** the data is encrypted, not a simple switch. `appDataEncryptionType` takes four values, and the default, **useDeviceSettings**, defers the question to the device, which is exactly the thing an unenrolled phone does not guarantee.

A pass needs one of **whenDeviceLocked**, **whenDeviceLockedExceptOpenFiles** or **afterDeviceRestart**, on a policy that is assigned.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **iOS** policy, or select **+ Create policy** and choose **iOS**.
4. Under **Data protection** > **Encryption**, set **Encrypt org data** to **Require**.
5. Set **Encrypt org data on enrolled devices** as your deployment requires, and choose an **Encrypt org data** option other than **Use device settings**.
6. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
7. Select **Next** and then **Create** or **Save**.

#### Related links

- [Microsoft Learn - iOS app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-ios)
- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - App protection policies overview](https://learn.microsoft.com/intune/app-management/protection/overview)

<!--- Results --->
%TestResult%
