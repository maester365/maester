When MFA is required during device registration in Conditional Access policies, it must be disabled in the Entra ID Device settings.

When both are enabled, the conditional access policy with the "Register device" user action will not work as expected.

#### Remediation action:

When a Conditional Access policy is configured with the **Register or join devices user action** you must disable tenant-wide multifactor requirement for device registration. Otherwise, Conditional Access policies with this user action are not properly enforced.

1. Open **[Entra - Device Settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Devices)**.
2. Set **Require Multifactor Authentication to register or join devices with Microsoft Entra** to **No**.

#### Related links

- [Require multifactor authentication for device registration](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-all-users-device-registration#create-a-conditional-access-policy)
- [Conflicting conditional access policies and Entra Device Settings](https://learn.microsoft.com/en-us/entra/identity/conditional-access/policy-all-users-device-registration#create-a-conditional-access-policy:~:text=When%20a%20Conditional%20Access%20policy%20is%20configured%20with%20the%20Register%20or%20join%20devices%20user%20action)

<!--- Results --->

%TestResult%
