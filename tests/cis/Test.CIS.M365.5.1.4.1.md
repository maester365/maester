The right to join devices to Microsoft Entra ID is limited to selected users or groups, or switched off.

A device that is joined to Microsoft Entra ID gets a device identity that can satisfy Conditional Access and, through Primary Refresh Tokens, enables single sign-on. If any user can join a device, an attacker with a stolen password can enrol a machine they control and obtain a trusted, managed-looking device.

Restricting the right to a group, for example your device provisioning team or an Autopilot service account, keeps the join step controlled.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Devices** > [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Users may join devices to Microsoft Entra** to **Selected** and choose the group or users, or to **None**.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [Manage device identities by using the Microsoft Entra admin center](https://learn.microsoft.com/entra/identity/devices/manage-device-identities)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
