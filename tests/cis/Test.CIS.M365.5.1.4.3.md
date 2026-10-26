5.1.4.3 (L1) Ensure the GA role is not added as a local administrator during Entra join

This setting controls whether the Global Administrator role is automatically added to the local administrators group on a device during the Microsoft Entra join process.

The recommended state is **No**.

#### Rationale

System administrators may be inclined to use over-privileged accounts for convenience when managing devices. Enforcing this control helps discourage that behavior by requiring administrative actions to be performed using accounts specifically designated for local administration. This promotes adherence to the principle of least privilege and reduces the risk associated with using high-level roles for routine tasks. For example, using a Global Administrator account to authenticate to a compromised endpoint and continue performing tasks significantly increases the risk of broader organizational compromise.

#### Impact

Restricting the default behavior and requiring manual assignment to least privilege roles introduces minor administrative overhead. During the Microsoft Entra join process, the Microsoft Entra Joined Device Local Administrator role is automatically added to the device's local administrators group and should be used instead.

#### Remediation action

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** > **Devices** and select [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Global administrator role is added as local administrator on the device during Microsoft Entra join (Preview)** to **No**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [How to manage the local administrators group on Microsoft Entra joined devices](https://learn.microsoft.com/entra/identity/devices/assign-local-admin)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.3](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
