5.1.4.6 (L2) Ensure users are restricted from recovering BitLocker keys

This setting determines if users can self-service recover their BitLocker key(s). Restricting non-admin users from being able to see the BitLocker key(s) for their owned devices is the recommended state.

#### Rationale

Restricting user access to the self-service BitLocker recovery key portal helps mitigate the risk of recovery key exposure in the event of a compromised user account. If an attacker gains access to both the user's credentials and the physical device, they could potentially retrieve the recovery key and decrypt sensitive data. The recovery key itself is also considered sensitive information.

#### Impact

Users will no longer be able to retrieve their own BitLocker recovery key(s) from the My Account portal or the Microsoft Entra admin center. They'll need to contact a Cloud Device Administrator, Helpdesk Administrator, Intune Administrator, Security Administrator, or Security Reader to recover the key, which increases the support burden during device recovery scenarios.

#### Remediation action:

1. Navigate to [Microsoft 365 Entra admin center](https://entra.microsoft.com).
2. Click to expand **Entra ID** and select **Devices** > **Device settings**.
3. Set **Restrict non-admin users from recovering the BitLocker key(s) for their owned devices** to **Yes**.
4. Click the **Save** option at the top of the window.

Alternatively, use Microsoft Graph PowerShell:

```powershell
Connect-MgGraph -Scopes Policy.ReadWrite.Authorization
$params = @{
	defaultUserRolePermissions = @{
		allowedToReadBitlockerKeysForOwnedDevice = $false
	}
}
Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy/authorizationPolicy" -Body $params
```

#### Related links

* [Microsoft 365 Entra admin center - Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Overview)
* [Manage devices in Microsoft Entra ID using the Microsoft Entra admin center](https://learn.microsoft.com/en-us/entra/identity/devices/manage-device-identities#configure-device-settings)
* [CIS Microsoft 365 Foundations Benchmark v6.0.1 - Control 5.1.4.6](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
