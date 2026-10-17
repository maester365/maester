Windows Local Administrator Password Solution (LAPS) is turned on for the tenant, so that the password of the built-in local administrator can be managed and backed up in Microsoft Entra ID.

When every device in a fleet has the same local administrator password, an attacker who gets it from one machine can use it on all the others. LAPS gives each device a unique, regularly rotated password and stores it centrally so that authorised support staff can retrieve it when they need to.

This setting turns the capability on in the tenant. You also need to configure the LAPS policy on the devices, for example with Microsoft Intune.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Devices** > [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Enable Microsoft Entra Local Administrator Password Solution (LAPS)** to **Yes**.
4. Select **Save**.
5. Create a LAPS policy in Microsoft Intune under **Endpoint security** > **Account protection** to make devices back up their password.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [Windows Local Administrator Password Solution in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/devices/howto-manage-local-admin-passwords)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.5](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
