Members of the Global Administrator role are not made local administrators of every device that joins Microsoft Entra ID.

When this setting is on, a single cloud admin account has administrative rights on every joined endpoint. Anyone who compromises that account, or one device where the admin signs in, can move to all the others, and tenant-wide admin credentials end up cached on workstations.

Use a dedicated, limited role such as Microsoft Entra Joined Device Local Administrator, or Intune-managed local administrator assignments and LAPS, for support tasks.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Devices** > [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Global administrator role is added as local administrator on the device during Microsoft Entra join (Preview)** to **No**.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [How to manage the local administrators group on Microsoft Entra joined devices](https://learn.microsoft.com/entra/identity/devices/assign-local-admin)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
