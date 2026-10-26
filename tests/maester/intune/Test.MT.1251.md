Ensure at least one **assigned** Android app protection policy requires Play Integrity device attestation.

A rooted Android phone has had the platform guarantees that the whole app protection model rests on removed. The app sandbox no longer separates the managed apps from everything else on the device, so the app PIN, the encrypted app data and the blocked data transfer all become settings enforced by code that another process can read and modify.

A device compliance policy can refuse a rooted device, but only one the organization **enrolled**. On an unenrolled phone the signal reaches the organization through the Play Integrity device attestation condition of the app protection policy.

Two values decide that together:

- **Require device attestation** (`requiredAndroidSafetyNetDeviceAttestationType`) is the gate: **none**, **basicIntegrity**, or **basicIntegrity and device certification**.
- The action when attestation fails (`appActionIfAndroidSafetyNetDeviceAttestationFailed`) is what happens at the gate. **Warn** leaves the data on a device whose integrity Google has declined to vouch for.

Note that the Graph property names still carry the SafetyNet name of the predecessor API; the Intune portal calls the feature Play Integrity.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **Android** policy, or select **+ Create policy** and choose **Android**.
4. Under **Conditional launch** > **Device conditions**, add **Device attestation** (listed as Play Integrity) and set it to **Check basic integrity** or **Check basic integrity and device certification**.
5. Set the action to **Block access** or **Wipe data**, not **Warn**.
6. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
7. Select **Next** and then **Create** or **Save**.

Device certification is the stricter option and will block devices Google has not certified, including some custom and region-specific builds. Pilot it before applying it broadly.

#### Related links

- [Microsoft Learn - Android app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-android)
- [Microsoft Learn - Data protection framework using app protection policies](https://learn.microsoft.com/intune/app-management/protection/data-protection-framework)
- [Microsoft Learn - Create and assign app protection policies](https://learn.microsoft.com/intune/app-management/protection/create-policy)

<!--- Results --->
%TestResult%
