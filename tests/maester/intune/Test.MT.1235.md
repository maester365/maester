Ensure at least one **assigned** Android compliance policy requires device threat protection.

Microsoft Defender for Endpoint on Android, and the other mobile threat defense connectors Intune supports, report what they find on a device: a malicious app, phishing web traffic, root, an unsafe network. Intune compliance policy consumes that verdict through **Require the device to be at or under the device threat level**, so a phone the service considers at risk is marked non-compliant and can then be blocked by Conditional Access.

Without this setting the detection never reaches the access decision. A phone with an active detection stays compliant and keeps its access to corporate resources, which removes exactly the automatic containment that a Zero Trust architecture assumes is present. Detection without enforcement leaves a compromised phone fully trusted.

The setting has no effect until the devices are onboarded to a mobile threat defense service and its connector is enabled and set to evaluate Android. Read a failure here together with [MT.1098](https://maester.dev/docs/tests/MT.1098), which checks the health of the connectors themselves.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Scope limitation

This test evaluates the **Android device administrator** compliance policy type (`androidCompliancePolicy`), and the boolean that requires threat protection. It does not read a required threat level value for this policy type, because that property name is not verified here.

Android Enterprise policies, for work profile and device owner enrollments, are counted and reported but their settings are not read. A tenant that has Android Enterprise policies and no device administrator policy is reported as **not applicable** rather than as a failure. A tenant with no Android compliance policy of any kind does fail.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Confirm a mobile threat defense connector is enabled and set to evaluate Android devices under **Tenant administration** > **[Connectors and tokens](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/TenantAdminMenu/~/mtdConnectors)**, or the Defender for Endpoint connector under **Endpoint security** > **[Microsoft Defender for Endpoint](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/mdeIntegration)**.
3. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
4. Select an existing **Android device administrator** policy. Intune ended support for Android device administrator on devices with access to Google Mobile Services on 31 December 2024, and Google has deprecated the management mode itself, so a new deployment should not be created on this platform; this step applies to the legacy policies a tenant still has. Android Enterprise compliance policies are counted by this test but their settings are not read, and the repository has no Android Enterprise compliance check for threat protection yet.
5. Under **Compliance settings** > **Microsoft Defender for Endpoint**, set **Require the device to be at or under the device threat level** to **Medium** or stricter.
6. On the **Assignments** tab, assign the policy to your Android device or user groups.
7. Select **Next** and then **Create** or **Save**.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Mobile Threat Defense with Intune](https://learn.microsoft.com/intune/device-security/mobile-threat-defense/overview)
- [Microsoft Learn - Deploy Microsoft Defender for Endpoint on Android](https://learn.microsoft.com/intune/device-security/microsoft-defender/deploy-android)

<!--- Results --->
%TestResult%
