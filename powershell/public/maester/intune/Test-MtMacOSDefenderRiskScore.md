Ensure at least one **assigned** macOS compliance policy requires a Microsoft Defender machine risk score level.

Microsoft Defender for Endpoint calculates a machine risk score for every onboarded device based on its active alerts and detections. Intune compliance policy can consume that score through **Require the device to be at or under the machine risk score**, so a Mac whose risk rises above an accepted threshold is marked non-compliant and can then be blocked by Conditional Access.

Without this setting the Defender signal never reaches the access decision. A Mac with active high-severity Defender alerts stays compliant and keeps its access to corporate resources, which removes exactly the automatic containment that a Zero Trust architecture assumes is present. Detection without enforcement leaves a compromised endpoint fully trusted.

The threshold accepts **Secured**, **Low**, **Medium** and **High**. The values *unavailable* and *notSet* mean the risk score is not evaluated at all, and neither counts as configured by this test.

Note that a threshold has no effect until the macOS devices are actually onboarded to Microsoft Defender for Endpoint and the Intune connector is enabled. This test reports whether **Require the device to be at or under the machine risk score** is paired with device threat protection, so a threshold that can never evaluate is visible.

#### Remediation action

1. Navigate to the [Microsoft Intune admin center](https://intune.microsoft.com).
2. Confirm the Defender for Endpoint connector is enabled under **Endpoint security** > **[Microsoft Defender for Endpoint](https://intune.microsoft.com/#view/Microsoft_Intune_Workflows/SecurityManagementMenu/~/mdeIntegration)**, and that **Connect macOS devices** is set to **On**.
3. Go to **Devices** > **Manage devices** > **[Compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)**.
4. Select an existing macOS policy, or select **+ Create policy** with **Platform** set to **macOS**.
5. Under **Compliance settings** > **Microsoft Defender for Endpoint**, set **Require the device to be at or under the machine risk score** to **Medium** or stricter.
6. On the **Assignments** tab, assign the policy to your macOS device or user groups.
7. Select **Next** and then **Create** or **Save**.

#### Related links

- [Microsoft Intune admin center - Device compliance](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/DevicesMenu/~/compliance)
- [Microsoft Learn - Device compliance settings for macOS in Intune](https://learn.microsoft.com/intune/device-security/compliance/ref-macos-settings)
- [Microsoft Learn - Enforce compliance for Microsoft Defender for Endpoint with Conditional Access](https://learn.microsoft.com/intune/device-security/advanced-threat-protection)
- [Microsoft Learn - Microsoft Defender for Endpoint on macOS](https://learn.microsoft.com/defender-endpoint/microsoft-defender-endpoint-mac)

<!--- Results --->
%TestResult%
