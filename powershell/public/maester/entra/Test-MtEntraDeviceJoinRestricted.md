## Description

Verifies that device join to Entra ID is restricted to selected users/groups or disabled entirely.

## Why This Matters

Device join should be restricted because:

- **Unauthorized Access**: Unrestricted device join allows any user to connect personal or unmanaged devices to corporate resources.
- **Data Leakage**: Uncontrolled devices may not have proper security controls, increasing risk of data exposure.
- **Compliance**: Many regulatory frameworks require controlled device access to organizational resources.
- **Shadow IT**: Unmanaged devices bypass security policies and monitoring capabilities.
- **Attack Surface**: Each joined device represents a potential entry point for attackers.

Restricting device join to selected users/groups ensures only authorized devices with proper security controls can access organizational resources.

#### Remediation action

This setting can be changed via device settings in the Microsoft Entra or Azure portal or via Microsoft Graph API / Graph PowerShell Module.

Admin Portal:

1. Go to [Entra Admin Center](https://entra.microsoft.com)
2. Navigate to Devices → [Device settings](https://entra.microsoft.com/#view/Microsoft_AAD_Devices/DevicesMenuBlade/~/DeviceSettings/menuId/Overview)
3. Set **Users may join devices to Microsoft Entra** to **Selected** or **None**
   - If **Selected**, configure the specific users/groups that can join devices
   - If **None**, disable device join entirely
4. Click **Save**

Use the following PowerShell commands to restrict device join:

```powershell
# Connect to Microsoft Graph with appropriate permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.DeviceConfiguration"

# Option 1: Disable device join completely
$params = @{
    azureADJoin = @{
        allowedToJoin = @{
            "@odata.type" = "#microsoft.graph.noDeviceRegistrationMembership"
        }
    }
}

# Option 2: Restrict to selected users/groups
$params = @{
    azureADJoin = @{
        allowedToJoin = @{
            "@odata.type" = "#microsoft.graph.enumeratedDeviceRegistrationMembership"
            users = @("user1@domain.com", "user2@domain.com")
            groups = @("group-id-1", "group-id-2")
        }
    }
}

# Apply the policy
Update-MgPolicyDeviceRegistrationPolicy -BodyParameter $params
```

#### Related links

- [Manage device identities in Entra ID](https://learn.microsoft.com/en-us/azure/active-directory/devices/overview)
- [Device registration policy in Entra ID](https://learn.microsoft.com/en-us/graph/api/resources/deviceregistrationpolicy)