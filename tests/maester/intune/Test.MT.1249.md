Ensure at least one **assigned** Android app protection policy acts on the device threat level.

A device compliance policy can refuse a rooted Android phone, but it only evaluates a device the organization **enrolled**. On an unenrolled phone the equivalent signal reaches the organization through the app protection policy: a mobile threat defense partner such as Microsoft Defender reports a threat level for the device, and the policy decides what the managed app does about it.

Two values decide that together:

- **Max allowed device threat level** (`maximumAllowedDeviceThreatLevel`) is the gate. **Not configured** means the signal is ignored.
- **Mobile threat defense remediation action** (`mobileThreatDefenseRemediationAction`) is what happens when the gate is crossed. **Warn** leaves the data available on a device the organization has been told is compromised.

A level of **high** accepts every threat the partner reports, so this test treats it as configured but not protective and reports it as a note.

On Android this complements the Play Integrity device attestation condition, which is checked separately. Attestation answers "is this device what it claims to be"; the threat level answers "has anything been found on it".

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an app protection policy with no assignment is never applied to a user.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Apps** > **App protection policies**.
3. Select an existing **Android** policy, or select **+ Create policy** and choose **Android**.
4. Set up a mobile threat defense connector and turn on **app protection policy evaluation** for Android (see the related link).
5. Under **Conditional launch** > **Device conditions**, add **Max allowed device threat level** with a value of **Secured**, **Low** or **Medium** and the action **Block access** or **Wipe data**.
6. On the **Assignments** tab, assign the policy to the user groups whose apps hold organization data.
7. Select **Next** and then **Create** or **Save**.

Without the connector the condition is configured and inert: nothing reports a threat level, so nothing is ever blocked. Verify the connector status in **Tenant administration** > **Connectors and tokens**.

#### Related links

- [Microsoft Learn - Configure Microsoft Defender for Endpoint integration with Intune](https://learn.microsoft.com/intune/device-security/microsoft-defender/configure-integration)
- [Microsoft Learn - Android app protection policy settings](https://learn.microsoft.com/intune/app-management/protection/ref-settings-android)
- [Microsoft Learn - App protection policies overview](https://learn.microsoft.com/intune/app-management/protection/overview)

<!--- Results --->
%TestResult%
