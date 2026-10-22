5.1.4.5 (L1) Ensure Local Administrator Password Solution is enabled

Local Administrator Password Solution (LAPS) is the management of local account passwords on Windows devices. LAPS provides a solution to securely manage and retrieve the built-in local admin password. With cloud version of LAPS, customers can enable storing and rotation of local admin passwords for both Microsoft Entra and Microsoft Entra hybrid join devices.

The recommended state is **Yes**.

#### Rationale

Managing local Administrator passwords across multiple systems can be challenging. As a result, many organizations opt to configure the same password on all workstations and/or member servers during deployment. However, this practice introduces a significant security risk: if an attacker compromises one system and obtains the local Administrator password, they can potentially gain administrative access to every other system using that same password.

Additionally, enabling LAPS at the tenant level is a prerequisite for implementing LAPS-related recommendations outlined in the CIS Microsoft Intune for Windows Workstation Benchmarks.

> **Note:** Enabling LAPS at the tenant level does not automatically enforce password rotation for built-in Administrator accounts. To activate LAPS functionality, appropriate policies must be configured in Intune Settings Catalog or under the **Endpoint security** > **Account protection** blade. The CIS Microsoft 365 Foundations Benchmark focuses on hardening at the tenant level, while the CIS Intune Benchmarks focus on endpoint-specific configurations.

#### Impact

Enabling LAPS requires some additional operational overhead.

Although unlikely if a password is rotated and not retrieved or backed up before the device becomes unreachable (e.g., due to hardware failure, network isolation, or being decommissioned), administrators may be locked out.

#### Remediation action

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** > **Devices** and select [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Enable Microsoft Entra Local Administrator Password Solution (LAPS)** to **Yes**.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [Windows Local Administrator Password Solution in Microsoft Entra ID](https://learn.microsoft.com/entra/identity/devices/howto-manage-local-admin-passwords)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.5](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
