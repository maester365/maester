Ensure at least one **assigned** Android compliance policy blocks devices managed with device administrator.

Android device administrator is the legacy management mode. Google deprecated the APIs it is built on, newer Android releases ignore a growing share of them, and the hardening that Android Enterprise brings - a separate work profile, Play Integrity attestation, per-profile policy - does not exist there. A device administrator enrollment is therefore managed in name while the controls an administrator believes are applied quietly stop being enforced.

The Android compliance policy can mark such enrollments non-compliant, which is how an organization drives the migration to Android Enterprise instead of discovering, years later, that part of the fleet was never protected.

This is a **modernization control**, not a defence against a particular technique, so it declares no ATT&CK mapping and a low severity. Its cost falls on users rather than on administrators: a device that is blocked has to be re-enrolled, and it loses access to corporate resources until it is. Plan the migration before you turn the setting on.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Scope limitation

A tenant with **no device administrator compliance policy at all** is reported as **not applicable**: the setting has nowhere to live, and having no such policy is the modern posture rather than a gap. [MT.1054](https://maester.dev/docs/tests/MT.1054) covers whether devices with no compliance policy assigned are treated as non-compliant.

Android Enterprise policies are counted and reported but their settings are not read by this test.

#### Remediation action

1. Find out what you have first: in the [Microsoft Intune admin center](https://intune.microsoft.com), go to **Devices** > **All devices** and group by **Managed by**, or check **Reports** > **Device management**. Devices enrolled with device administrator have to be re-enrolled into Android Enterprise, which is user work.
2. Set up Android Enterprise enrollment under **Devices** > **Enrollment** > **Android** if it is not configured, and move your groups over.
3. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
4. Select the Android device administrator policy, or select **+ Create policy** with **Platform** set to **Android device administrator**.
5. Under **Compliance settings** > **Device Health**, set **Devices managed with device administrator** to **Block**.
6. On the **Assignments** tab, assign the policy to your Android device or user groups.
7. Configure **Actions for noncompliance** with a grace period and a notification, so users are told to re-enroll before they lose access.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Android device administrator compliance settings in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-android-administrator-settings)
- [Microsoft Learn - Android device enrollment guide for Intune](https://learn.microsoft.com/intune/device-enrollment/android/guide)

<!--- Results --->
%TestResult%
