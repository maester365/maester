# Entra: Tests if Entra ID tenant creation is restricted to admin users.

## Overview

**Function Name:** `Test-MtTenantCreationRestricted`
**Category:** Maester/Entra
**Test Tag:** `Entra`

## Description

This function checks if the Entra ID tenant creation is restricted to admin users by querying the authorization policy settings.

## Workflow

```mermaid
flowchart TD
    A[Start] --> B{Prerequisites Check}
    B -->|Connection Required| C{Check Connections}
    C -->|Microsoft Graph| D{License Check}
    D -->|No specific license| E[Data Collection]
    E --> F[Compliance Validation]
    F --> G{Return Result}
    G -->|Pass| I[Return True]
    G -->|Fail| J[Return False]
    B -->|Not Connected| K[Return Null - Skipped]
```

## Phase Details

### Phase 1: Prerequisites Check

**Required Connections:**
- Microsoft Graph

### Phase 2: Data Collection

**Graph API Calls:**
- `policies/authorizationPolicy?$select=defaultUserRolePermissions`

**Cmdlets/Functions Used:**
- `Invoke-MtGraphRequest`

### Phase 3: Compliance Validation

The function validates the collected data against compliance requirements.

### Phase 4: Return Result

| Return Value | Meaning |
| --- | --- |
| `$true` | Compliant |
| `$false` | Non-Compliant |
| `$null` | Skipped (missing prerequisites, license, or error) |

## Original Documentation

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

## Standalone Function

See the standalone compliance check function: [`Test-MtTenantCreationRestrictedCompliance.ps1`](../../standalone-functions/Maester/Entra/Test-MtTenantCreationRestrictedCompliance.ps1)
