5.1.4.2 (L1) Ensure the maximum number of devices per user is limited

This setting defines the maximum number of Microsoft Entra joined or registered devices that a user can have in Microsoft Entra ID. Once this limit is reached, no additional devices can be added until existing ones are removed. Values above 100 are automatically capped at 100.

The recommended state is **10** or less.

#### Rationale

Microsoft incident response teams have observed threat actors enrolling their own devices to establish persistence after a non-privileged user has been compromised. High device quotas can exacerbate this risk by enabling attackers to register multiple devices that appear legitimate, while also contributing to unmanaged or personal devices cluttering the environment, driving up licensing costs and complicating compliance efforts.

Enforcing a reasonable device limit per user supports good governance, reduces the attack surface, and encourages administrators to reassess and clean up legacy or unused device enrollments.

#### Impact

IT staff who need to enroll more than 10 devices on behalf of the organization must be assigned the role of Device Enrollment Manager in the Intune admin center. Device Enrollment Managers are non-administrator accounts that can enroll and manage up to 1,000 devices. It is recommended to use dedicated service accounts for this role rather than assigning it to users' primary or daily-use accounts.

> **Warning:** Do not delete accounts assigned as a Device enrollment manager if any devices were enrolled using the account. Doing so will lead to issues with these devices.

#### Remediation action

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** > **Devices** and select [**Device settings**](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices).
3. Set **Maximum number of devices per user** to **10** or less.

#### Related links

* [Microsoft Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)
* [Manage device identities by using the Microsoft Entra admin center](https://learn.microsoft.com/entra/identity/devices/manage-device-identities)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.4.2](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
