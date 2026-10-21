Ensure at least one **assigned** iOS compliance policy requires a Microsoft Defender machine risk score level.

Microsoft Defender for Endpoint on iOS calculates a machine risk score for every onboarded device from what it detects on it: malicious or phishing web traffic, a jailbreak, a known bad app, an unsafe network. Intune compliance policy consumes that verdict through **Require the device to be at or under the machine risk score**, so an iPhone whose risk rises above an accepted threshold is marked non-compliant and can then be blocked by Conditional Access.

Without this setting the detection never reaches the access decision. A phone with an active high severity detection stays compliant and keeps its access to corporate resources, which removes exactly the automatic containment that a Zero Trust architecture assumes is present. Detection without enforcement leaves a compromised phone fully trusted.

The threshold accepts **Secured**, **Low**, **Medium** and **High**. The values *unavailable* and *notSet* mean the risk score is not evaluated at all, and neither counts as configured by this test.

A threshold has no effect until the devices are actually onboarded to Defender for Endpoint and the Intune connector is enabled for iOS. This test reports whether the threshold is paired with **Require the device to be at or under the device threat level**, so a threshold that can never evaluate is visible. [MT.1098](https://maester.dev/docs/tests/MT.1098) checks the health of the connectors themselves.

#### Scope limitation

This test reads the **Defender for Endpoint** machine risk score threshold. A tenant that uses a third party mobile threat defense connector instead configures a separate threshold property, which this test does not read, so such a tenant can fail this check while being correctly configured. Check the connectors in the Intune admin center before acting on a failure here.

Policies that are **not assigned** to any group are reported by this test but do not count towards a pass, because an unassigned compliance policy is never evaluated against any device.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Confirm the Defender for Endpoint connector is enabled under **Endpoint security** > **[Microsoft Defender for Endpoint](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/mdeIntegration)**, and that **Connect iOS/iPadOS devices** is set to **On**.
3. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
4. Select an existing iOS/iPadOS policy, or select **+ Create policy** with **Platform** set to **iOS/iPadOS**.
5. Under **Compliance settings** > **Microsoft Defender for Endpoint**, set **Require the device to be at or under the machine risk score** to **Medium** or stricter.
6. On the **Assignments** tab, assign the policy to your iOS device or user groups.
7. Select **Next** and then **Create** or **Save**.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - iOS/iPadOS compliance settings in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-ios-ipados-settings)
- [Microsoft Learn - Mobile Threat Defense with Intune](https://learn.microsoft.com/intune/device-security/mobile-threat-defense/overview)
- [Microsoft Learn - Deploy Microsoft Defender for Endpoint on iOS](https://learn.microsoft.com/defender-endpoint/ios-install)

<!--- Results --->
%TestResult%
