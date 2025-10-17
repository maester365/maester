This test checks if tenant creation is restricted to admin users only.

"Yes" restricts the creation of Microsoft Entra ID tenants to the global administrator or tenant creator roles. "No" allows non-admin users to create Microsoft Entra ID tenants. Anyone who creates a tenant will become the global administrator for that tenant.

Tenant creation should be restricted to admin users who have undergone proper training and understand the responsibilities of tenant management, security governance, and compliance requirements.

#### Remediation action

This setting can be changed via user settings in the Microsoft Entra or Azure portal or via Microsoft Graph API / Graph PowerShell Module.

Admin Portal:

1. Go to [Entra Admin Center](https://entra.microsoft.com)
2. Navigate to Users → [User settings](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/)
3. Set **Restrict non-admin users from creating tenants** to **Yes**
4. Click **Save**

Use the following PowerShell commands to restrict tenant creation:

```powershell
# Connect to Microsoft Graph with appropriate permissions
Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"

# Get the current authorization policy
$authPolicy = Get-MgPolicyAuthorizationPolicy

# Update the policy to restrict tenant creation
$params = @{
    defaultUserRolePermissions = @{
        allowedToCreateTenants = $false
    }
}

Update-MgPolicyAuthorizationPolicy -AuthorizationPolicyId $authPolicy.Id -BodyParameter $params
```

#### Related links

- [Manage default user permissions in Entra ID](https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/users-default-permissions)
- [Authorization policy in Entra ID](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)
