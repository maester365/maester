Ensure at least one **assigned** Android compliance policy requires a strong device password.

The device password is what stands between someone holding the phone and everything on it: corporate mail, Teams conversations, and the Microsoft Authenticator app, which is the second factor for the signed-in user. A phone with no password hands all of that to whoever picks it up, and a stolen phone is the most ordinary way a mobile device is lost to someone else.

Three settings make up the control, and this check requires all three **on the same policy**, because a device is evaluated against each policy as a whole:

- **Require a password to unlock mobile devices** - without it, nothing below applies.
- **Minimum password length** - six characters by default in this check.
- **Maximum minutes of inactivity before password is required** - fifteen minutes by default. A password on a screen that never locks protects nothing.

An inactivity timeout that is **not configured** does not count as a pass. Treating a missing value as "no limit, so under the limit" would report the weakest possible configuration as compliant.

The **required password complexity** is shown for every policy but does not decide the verdict, because the set of values that property accepts has not been verified against the live schema for this policy type. An unrecognised value is printed as Intune returned it rather than relabelled.

Both thresholds are parameters, so an organization that requires eight characters and a five minute lock can set `MinimumPasswordLength` and `MaximumInactivityMinutes` in its Maester configuration.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Scope limitation

This test evaluates the **Android device administrator** compliance policy type (`androidCompliancePolicy`). Android Enterprise policies, for work profile and device owner enrollments, are counted and reported but their settings are not read, because their property names are not verified here.

A tenant that has Android Enterprise policies and no device administrator policy is reported as **not applicable** rather than as a failure. A tenant with no Android compliance policy of any kind does fail, because then nothing evaluates Android devices at all.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
3. Select an existing Android policy, or select **+ Create policy** with **Platform** set to **Android device administrator**.
4. Under **Compliance settings** > **System Security** > **Password**:
   - Set **Require a password to unlock mobile devices** to **Require**.
   - Set **Minimum password length** to **6** or more.
   - Set **Maximum minutes of inactivity before password is required** to **15** or less.
5. On the **Assignments** tab, assign the policy to your Android device or user groups.
6. Select **Next** and then **Create** or **Save**.

Tell users before the policy applies: devices that do not meet the requirement prompt for a new password, and users with a short PIN have to choose a longer one.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Android device administrator compliance settings in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-android-administrator-settings)
- [Microsoft Learn - Levels of protection and configuration in Intune](https://learn.microsoft.com/intune/fundamentals/protection-configuration-levels)

<!--- Results --->
%TestResult%
