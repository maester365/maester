---
title: Emergency Access Accounts
sidebar_position: 2
---

# Configuring Emergency Access Accounts

Emergency access accounts (also known as "break glass" accounts) are highly privileged accounts that should be excluded from all Conditional Access policies to ensure you can always access your tenant in case of a lockout scenario.

Maester includes tests that verify your emergency access accounts are properly excluded from all Conditional Access policies. By configuring your emergency access accounts in the Maester configuration, these tests can validate that your specific accounts are correctly excluded.

## Why Configure Emergency Access Accounts?

By default, Maester attempts to auto-detect emergency access accounts by looking for users or groups that are consistently excluded from all Conditional Access policies. However, explicitly configuring your emergency access accounts provides:

- **Accurate testing** - Ensures the exact accounts you intend as emergency access are being validated
- **Clear documentation** - Your configuration serves as documentation of your emergency access strategy
- **Support for multiple accounts** - Define multiple users and groups as emergency access accounts

## Configuration Format

Emergency access accounts are configured in the `GlobalSettings` section of your custom `maester-config.json` file.

### Basic Structure

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      // Your emergency access accounts and groups
    ]
  }
}
```

### Supported Parameters

Each entry in the `EmergencyAccessAccounts` array supports the following parameters:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Type` | Yes | The type of object. Must be either `User` or `Group` |
| `Id` | No* | The Object ID (GUID) of the user or group |
| `UserPrincipalName` | No* | The UPN (email) of the user or group email address |

\* You must provide either `Id` or `UserPrincipalName` for each entry.

## Configuration Examples

### Single Emergency Access User (using UPN)

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      {
        "UserPrincipalName": "BreakGlass1@contoso.com",
        "Type": "User"
      }
    ]
  }
}
```

### Single Emergency Access User (using Object ID)

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      {
        "Id": "00000000-0000-0000-0000-000000000001",
        "Type": "User"
      }
    ]
  }
}
```

### Emergency Access Group

If you use a security group to manage your emergency access accounts, you can configure the group instead:

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      {
        "Id": "00000000-0000-0000-0000-000000000002",
        "Type": "Group"
      }
    ]
  }
}
```

### Multiple Emergency Access Accounts

Microsoft recommends having at least two emergency access accounts. You can configure multiple users and groups:

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      {
        "UserPrincipalName": "BreakGlass1@contoso.com",
        "Type": "User"
      },
      {
        "UserPrincipalName": "BreakGlass2@contoso.com",
        "Type": "User"
      },
      {
        "Id": "00000000-0000-0000-0000-000000000002",
        "Type": "Group"
      }
    ]
  }
}
```

:::tip
When you configure both users and groups, Maester will verify that **all** configured accounts and groups are excluded from every Conditional Access policy.
:::

## Finding Object IDs

### For Users

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Navigate to **Users** > **All users**
3. Search for your emergency access user
4. Copy the **Object ID** from the user's overview page

Or use PowerShell:

```powershell
Get-MgUser -UserId "BreakGlass1@contoso.com" | Select-Object Id, UserPrincipalName
```

### For Groups

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Navigate to **Groups** > **All groups**
3. Search for your emergency access group
4. Copy the **Object ID** from the group's overview page

Or use PowerShell:

```powershell
Get-MgGroup -Filter "displayName eq 'Emergency Access Accounts'" | Select-Object Id, DisplayName
```

## Related Tests

The following Maester tests use the Emergency Access Accounts configuration:

| Test ID | Description |
|---------|-------------|
| MT.1005 | All Conditional Access policies are configured to exclude at least one emergency/break glass account or group |

## Best Practices

1. **Use at least two emergency access accounts** - Microsoft recommends having multiple break glass accounts in case one is compromised or unavailable.

2. **Use cloud-only accounts** - Emergency access accounts should not be synchronized from on-premises Active Directory.

3. **Exclude from all Conditional Access policies** - Ensure your emergency access accounts are excluded from ALL policies, not just MFA policies.

4. **Monitor emergency account usage** - Set up alerts for when emergency access accounts are used.

5. **Test regularly** - Periodically verify that your emergency access accounts can actually sign in and access critical resources.

## Learn More

- [Microsoft documentation on managing emergency access accounts](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)
- [Best practices for emergency access accounts](https://learn.microsoft.com/entra/identity/role-based-access-control/security-planning#stage-2-mitigate-frequently-used-attacks)
