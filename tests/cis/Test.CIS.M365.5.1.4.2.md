The maximum number of devices that a user can join or register in Microsoft Entra ID is capped at a low number.

A high limit lets one compromised account register many devices. Each registered device can hold tokens for the account and can be used to hide among legitimate devices. A low cap limits the number that can be created and makes unusual registration activity easier to notice.

This is a tenant-level setting for the maximum number of devices each user can join or register. When a user reaches the limit, they must remove an existing device before adding another.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Devices** > [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Maximum number of devices per user** to 10 or lower.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [Manage device identities by using the Microsoft Entra admin center](https://learn.microsoft.com/entra/identity/devices/manage-device-identities)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
