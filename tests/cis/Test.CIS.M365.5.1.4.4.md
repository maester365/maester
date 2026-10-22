5.1.4.4 (L1) Ensure local administrator assignment is limited during Entra join

This setting determines if the Microsoft Entra user registering their device as Microsoft Entra join will be added to the local administrators group. This setting applies only once during the actual registration of the device as Microsoft Entra join.

The recommended state is **Selected** or **None**.

#### Rationale

To uphold the principle of least privilege, the assignment of local administrator rights during Microsoft Entra join should be centrally managed using appropriate built-in roles through Intune. This approach minimizes the number of disparate users with elevated privileges, reducing the attack surface and potential for misuse. Centralized management also streamlines the deprovisioning process, ensuring that administrative access can be revoked efficiently and consistently across all devices, rather than requiring manual intervention on each individual endpoint.

#### Impact

Restricting the default behavior and requiring manual assignment to built-in roles introduces minor administrative overhead. During the Microsoft Entra join process, the Microsoft Entra Joined Device Local Administrator role is automatically added to the device's local administrators group and should be used instead.

#### Remediation action

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** > **Devices** and select [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Registering user is added as local administrator on the device during Microsoft Entra join (Preview)** to **Selected** (and add members) or **None**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [How to manage the local administrators group on Microsoft Entra joined devices](https://learn.microsoft.com/entra/identity/devices/assign-local-admin)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
