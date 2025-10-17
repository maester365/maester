## Description

Verifies that security group creation is restricted to admin users only in the Entra ID tenant.

## Why This Matters

Restricting security group creation to administrators ensures proper governance, maintains the principle of least privilege, and supports regulatory compliance requirements.

#### Remediation action

This setting can be changed via user settings in the Microsoft Entra or Azure portal or via Microsoft Graph API / Graph PowerShell Module.

Admin Portal:

1. Go to [Entra Admin Center](https://entra.microsoft.com)
2. Navigate to Users → [User settings](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/)
3. Set **Users can create security groups** to **No**
4. Click **Save**

Use the following PowerShell commands to restrict security group creation:

```powershell
# Connect to Microsoft Graph with appropriate permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"

# Get the current authorization policy
$authPolicy = Get-MgPolicyAuthorizationPolicy

# Update the policy to restrict security group creation
$params = @{
    defaultUserRolePermissions = @{
        allowedToCreateSecurityGroups = $false
    }
}

Update-MgPolicyAuthorizationPolicy -AuthorizationPolicyId $authPolicy.Id -BodyParameter $params
```

#### Related links

- [Manage default user permissions in Entra ID](https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/users-default-permissions)
- [Authorization policy in Entra ID](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)