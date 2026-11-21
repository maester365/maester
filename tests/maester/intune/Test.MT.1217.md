Ensure macOS Automated Device Enrollment profiles provision a managed local administrator account with password rotation.

**The Intune implementation of macOS LAPS is not a policy.** Unlike Windows LAPS, which is a settings catalog policy, macOS LAPS is configured on the **Automated Device Enrollment (ADE) profile** itself, on the **Account Settings** tab. There is no configuration policy or Endpoint Security profile to look for.

When configured, every device enrolling through that ADE profile is provisioned with a local administrator account whose 15-character password is generated, encrypted and stored by Intune, then rotated automatically. Administrators holding the required RBAC permission can retrieve it or rotate it on demand.

Without it, macOS fleets are typically built with a single shared local administrator password baked into an image or a provisioning script. That credential is identical on every Mac, is never rotated, and is the classic lateral-movement primitive: one recovered password grants local administrator access across the entire fleet. Attackers harvest it from scripts, configuration management, or a single compromised device.

Two properties matter beyond mere presence:

- **A rotation setting must exist.** An admin account with no rotation configuration is a static password, which defeats the purpose.
- **Rotate on retrieval should be enabled**, so the password changes after an administrator views it. Without it, every past viewing remains a valid credential until the next scheduled rotation.

#### Scope limitation

macOS LAPS applies only to devices that enroll through ADE **after a factory reset**. Enrollment flows that re-initiate ADE from an existing macOS installation (for example `profiles renew`) are not supported. A passing result therefore describes newly enrolled devices, not necessarily the whole estate - existing Macs must be re-enrolled to be covered.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Go to **Devices** > **Enrollment** > **[Apple](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/EnrollmentMenu/~/appleEnrollment)** > **Enrollment program tokens**.
3. Select your token, then **Profiles**, and select or create a macOS enrollment profile.
4. On the **Account Settings** tab, set **Local administrator account** to **Yes**.
5. Configure the account options. For profiles without user device affinity, use `{{serialNumber}}-admin` as the **Admin account username** so each device is unique.
6. Set **Admin account password rotation period (days)** to a value between 1 and 180.
7. Set **Hide in Users & Groups** to hide the managed account from the sign-in window.
8. Select **Next** and then **Save**.

To view or rotate a password, an administrator needs a [custom Intune role](https://learn.microsoft.com/intune/fundamentals/role-based-access-control/create-custom-role) with **Enrollment programs** > **View macOS admin password** and **Rotate macOS admin password** set to **Yes**. Neither permission is included in any built-in role, including Intune Administrator.

#### Related links

- [Microsoft Intune admin center - Apple enrollment](https://intune.microsoft.com/#view/Microsoft_Intune_Enrollment/EnrollmentMenu/~/appleEnrollment)
- [Microsoft Learn - Configure macOS ADE local account configuration with LAPS](https://learn.microsoft.com/intune/device-security/laps/setup-macos)
- [Microsoft Learn - Rotate local admin password (macOS)](https://learn.microsoft.com/intune/device-management/actions/rotate-local-admin-password?pivots=macos)
- [Microsoft Learn - Configure Intune for Zero Trust: Secure devices](https://learn.microsoft.com/intune/device-security/ref-zero-trust-devices)

<!--- Results --->
%TestResult%
