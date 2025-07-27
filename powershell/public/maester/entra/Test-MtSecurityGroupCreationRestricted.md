## Description

Verifies that security group creation is restricted to admin users only in the Entra ID tenant.

## Why This Matters

Restricting security group creation to administrators ensures proper governance, maintains the principle of least privilege, and supports regulatory compliance requirements.

#### Remediation action

This setting can be changed via user settings in the Microsoft Entra or Azure portal or via Microsoft Graph API / Graph PowerShell Module.

Admin Portal:
1. Go to https://entra.microsoft.com (sign in as Global Admin)
2. Navigate to Users → User settings
3. Find "Users can create security groups " setting
4. Change from "Yes" to "No"
5. Click Save

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