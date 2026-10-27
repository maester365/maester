5.1.4.1 (L2) Ensure the ability to join devices to Entra is restricted

This setting enables you to select the users who can register their devices as Microsoft Entra joined devices.

The recommended state is **Selected** or **None**.

> **Note:** This setting is applicable only to Microsoft Entra join on Windows 10 or newer. This setting doesn't apply to Microsoft Entra hybrid joined devices, Microsoft Entra joined VMs in Azure, or Microsoft Entra joined devices that use Windows Autopilot self-deployment mode because these methods work in a userless context.

#### Rationale

If a threat actor compromises a standard user account, they can enroll a rogue device under that user's identity. This device may inherit MDM policies and appear compliant, giving attackers persistent access to cloud resources without triggering MFA.

In a 2023 blog, Microsoft IR reports that it has detected threat actors registering their own devices to the Microsoft Entra tenant, giving them a platform to escalate the cyberattack. While simply joining a device to a Microsoft Entra tenant may present limited immediate risk, it could allow a threat actor to establish a foothold in the environment.

#### Impact

Restricting the setting requires IT teams to assign enrollment permissions to specific staff, such as helpdesk or provisioning personnel, which may impact user-driven Autopilot scenarios and increase administrative overhead for device onboarding and support.

#### Remediation action

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** > **Devices** and select [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Users may join devices to Microsoft Entra** to **Selected** (and add members) or **None**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [Manage device identities by using the Microsoft Entra admin center](https://learn.microsoft.com/entra/identity/devices/manage-device-identities)
* [Microsoft Incident Response lessons on preventing cloud identity compromise](https://www.microsoft.com/security/blog/2023/12/05/microsoft-incident-response-lessons-on-preventing-cloud-identity-compromise/)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
