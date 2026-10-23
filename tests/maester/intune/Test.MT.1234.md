Ensure at least one **assigned** Android compliance policy requires a recent security patch level.

Android publishes a **security patch level**, a date, that says which monthly security bulletin a device has received. It is the only practical way to tell whether a phone carries the fixes for the kernel and media vulnerabilities Google has published, because the Android version alone does not say: two phones on the same release can be a year apart in patches, which is routine on devices whose manufacturer has stopped shipping updates.

A minimum security patch level in a compliance policy is how the tenant notices. A device below the date is marked non-compliant and can then be blocked by Conditional Access.

A date that is itself old makes the setting pointless: a policy that requires patches from three years ago accepts every device while looking configured in the portal. This check therefore requires both that the setting is configured **and** that the date is no older than `MaximumPatchLevelAgeInDays`, which is one year by default and can be set in the Maester configuration.

A value that cannot be read as a date is reported with its raw value and does not count towards a pass, rather than being guessed at in either direction.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Scope limitation

This test evaluates the **Android device administrator** compliance policy type (`androidCompliancePolicy`). Android Enterprise policies, for work profile and device owner enrollments, are counted and reported but their settings are not read, because their property names are not verified here.

A tenant that has Android Enterprise policies and no device administrator policy is reported as **not applicable** rather than as a failure. A tenant with no Android compliance policy of any kind does fail, because then nothing evaluates Android devices at all.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
3. Select an existing Android policy, or select **+ Create policy** with **Platform** set to **Android device administrator**.
4. Under **Compliance settings** > **Device Properties**, set **Minimum security patch level** to a recent date, for example the bulletin from six months ago.
5. On the **Assignments** tab, assign the policy to your Android device or user groups.
6. Select **Next** and then **Create** or **Save**.
7. Put a reminder in your own calendar to move the date forward: a patch level set once and forgotten stops being a control.

Check the patch levels your fleet reports in **Devices** > **All devices** before you set the date. Devices whose manufacturer no longer ships updates will never meet it and have to be replaced.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Android device administrator compliance settings in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-android-administrator-settings)
- [Android Open Source Project - Android security bulletins](https://source.android.com/docs/security/bulletin)

<!--- Results --->
%TestResult%
