Users who join a device to Microsoft Entra ID do not automatically become local administrators; this is limited to selected users or groups, or to nobody.

Local administrators can disable security tools, install software, dump credentials and change the device configuration. Making everyone who joins a device an administrator removes the barrier that endpoint protection relies on.

Grant local administrator rights only to the people who need them, through a group or an Intune policy, and prefer time-limited elevation.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Devices** > [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Registering user is added as local administrator on the device during Microsoft Entra join (Preview)** to **Selected** and choose the group, or to **None**.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [How to manage the local administrators group on Microsoft Entra joined devices](https://learn.microsoft.com/entra/identity/devices/assign-local-admin)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
