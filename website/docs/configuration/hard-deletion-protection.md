---
title: Hard Deletion Protection
sidebar:
  order: 3
---

# Configuring Hard Deletion Protection

Hard Deletion Protection (preview) is a Microsoft Entra feature that stops a protected object from being permanently deleted during the first seven days after it is soft deleted. The object can still be soft deleted and restored, so you have time to notice the deletion, investigate it and recover the object.

Maester includes tests that check the objects you list in the Maester configuration against their Hard Deletion Protection setting in Microsoft Entra.

:::caution
Protection is **permanent**. Once enabled on an object it cannot be removed. If you enable it by mistake, soft delete the object and wait seven days before you permanently delete it. Microsoft intends the feature for selected critical objects, not for every object in the tenant.
:::

## How Hard Deletion Protection Works

- The seven-day protection window starts when the object is soft deleted.
- An attempt to permanently delete the object during the window is blocked. In testing, Microsoft Graph returned `403 Forbidden` with the `Authorization_RequestDenied` error code and a message that gives the time the window ends. The Microsoft Graph reference documents `409 Conflict` for this case, so match on the message and not on the status code if you build detection around it.
- After the window ends, the object can be permanently deleted as normal.
- If you restore the object, protection stays enabled. If you soft delete it again, a new seven-day window starts.
- Protection can only be enabled on active (not deleted) objects.
- Enabling protection is recorded in the Microsoft Entra audit logs.

Supported objects:

| Object | Notes |
|--------|-------|
| Users | Cloud-only users, including guests. Users synchronized from on-premises Active Directory are not supported. |
| Groups | Cloud-only Microsoft 365 and security groups. Mail-enabled security groups and distribution groups are not supported. |
| Applications | App registrations in your tenant. |
| Service principals | Service principals in your tenant, such as enterprise applications. Some system-created service principals, such as those for Azure Automation accounts, cannot be protected. |

Microsoft Entra Agent ID objects are supported through their underlying user, application and service principal types. No additional license is required.

## Configuration Format

Hard Deletion Protection objects are configured in the `GlobalSettings` section of your custom `maester-config.json` file.

### Basic Structure

```json
{
  "GlobalSettings": {
    "HardDeletionProtectedObjects": [
      // The critical objects that must be protected
    ]
  }
}
```

### Supported Parameters

Each entry in the `HardDeletionProtectedObjects` array supports the following parameters:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Type` | Yes | The type of object. Must be `User`, `Group`, `Application` or `ServicePrincipal` |
| `Id` | Yes | The Object ID (GUID) of the object |

For an application, use the **Object ID** of the app registration, not the Application (client) ID. For a service principal, use the Object ID of the enterprise application.

## Configuration Examples

```json
{
  "GlobalSettings": {
    "HardDeletionProtectedObjects": [
      { "Type": "User", "Id": "00000000-0000-0000-0000-000000000001" },
      { "Type": "Group", "Id": "00000000-0000-0000-0000-000000000002" },
      { "Type": "Application", "Id": "00000000-0000-0000-0000-000000000003" },
      { "Type": "ServicePrincipal", "Id": "00000000-0000-0000-0000-000000000004" }
    ]
  }
}
```

## What the Test Reports

| Situation | Result |
|-----------|--------|
| Every listed object has protection enabled, and no other object in Microsoft Entra has protection | **Passed** |
| Every listed object has protection enabled, but other objects in Microsoft Entra have protection and are not listed | **Investigate**. The other objects are listed so you can decide whether they belong in the configuration |
| A listed object does not have protection enabled, or Microsoft Entra returns no value for it | **Failed**, and the object is listed in the result |
| A listed object is soft deleted | **Failed**, and the object is listed with the status `Soft deleted` |
| A listed object does not exist | **Failed**, and the object is listed with the status `Not found` |
| No objects are listed in the configuration | **Investigate**. Protection has to be verified manually. The objects that already have protection in Microsoft Entra are listed to help you build the configuration |

Microsoft Graph returns `null` for an object that is not protected, so an unprotected object and an object that cannot be protected (such as a synchronized user) both appear as not protected.

The result lists at most 25 objects in each table and gives the total when there are more. Each table shows the object type, object ID, display name, and whether the object is active or soft deleted. A failed result also lists the objects that have protection but are not in the configuration, so you can see both gaps at once.

## Which Objects to Protect

Protect the objects whose permanent loss would be hard to recover from or would help an attacker hide their tracks. These are suggestions, not requirements. Start small and add objects as you decide they are critical.

### Users

- **Emergency access (break glass) accounts** - Losing them can lock you out of the tenant. See [Emergency Access Accounts](./emergency-access-accounts.md).
- **Administrators** - Global Administrators and other holders of privileged roles. Protection can stop a departing administrator or an attacker from removing the accounts that can undo their changes.
- **Executives and other VIP accounts** - Accounts with high-value mailboxes and data, and accounts that are often targeted.
- **Critical business accounts** - Finance, HR and legal approvers, and accounts that own critical processes.
- **Dedicated service accounts** - Cloud-only user accounts that applications or integrations sign in with.

### Groups

- **Role-assignable groups** - Groups that grant Microsoft Entra roles.
- **Groups used in Conditional Access policies** - Groups that policies include or exclude, such as emergency access or exception groups.
- **Groups that grant access to sensitive apps or data** - Including the Microsoft 365 groups behind critical teams and sites.

### Applications and service principals

- **Applications with high-privilege permissions** - For example Microsoft Graph application permissions that can read or change many objects.
- **Line-of-business and single sign-on apps** - Apps that many users depend on to work.
- **Automation and pipeline identities** - Apps and service principals used by deployment pipelines, backup tools and security tooling, and the workload identities behind agents.
- **Identity infrastructure apps** - Apps that other services or federation depend on.

### What not to protect

- Test and temporary objects, since protection cannot be undone.
- Users synchronized from on-premises Active Directory, which are not supported.
- Whole categories of objects. The feature is not designed for blanket protection, and you can protect only 20 objects of one type per operation in the portal.

## Enabling Protection

Maester does not enable protection. Use the Microsoft Entra admin center or Microsoft Graph.

### Microsoft Entra admin center

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com) as at least a **Microsoft Entra Backup Administrator**.
2. Browse to **Backup and recovery** > **Hard deletion protection**.
3. Select **Add protection** and choose one object type.
4. Select up to 20 objects and review the permanent-protection warning.
5. Select **Save**.

### Microsoft Graph

Set `isHardDeleteProtectionEnabled` to `true` on the object with the Microsoft Graph beta endpoint. The calling app or user needs the `HardDeletionSetting.ReadWrite.Enable` permission and the Global Administrator or Backup Administrator role.

```powershell
Connect-MgGraph -Scopes 'HardDeletionSetting.ReadWrite.Enable'

$body = @{ isHardDeleteProtectionEnabled = $true }
Invoke-MgGraphRequest -Method PATCH -Uri 'https://graph.microsoft.com/beta/users/<object-id>' -Body $body
```

Use `groups`, `applications` or `servicePrincipals` in place of `users` for the other object types.

## Finding Object IDs

### In the Microsoft Entra admin center

1. Go to the [Microsoft Entra admin center](https://entra.microsoft.com)
2. Open **Users**, **Groups**, **App registrations** or **Enterprise applications**
3. Search for the object
4. Copy the **Object ID** from its overview page

### With PowerShell

```powershell
Get-MgUser -UserId "admin@contoso.com" | Select-Object Id, UserPrincipalName
Get-MgGroup -Filter "displayName eq 'Privileged Access Group'" | Select-Object Id, DisplayName
Get-MgApplication -Filter "displayName eq 'Contoso Deployment'" | Select-Object Id, DisplayName
Get-MgServicePrincipal -Filter "displayName eq 'Contoso Deployment'" | Select-Object Id, DisplayName
```

## Related Tests

| Test ID | Description |
|---------|-------------|
| MT.1276 | Critical Entra objects should have Hard Deletion Protection enabled (Preview) |

MT.1276 is a preview test. Run it with the `-IncludePreview` switch of `Invoke-Maester`.

## Best Practices

1. **Protect deliberately** - Protection is permanent, so list only the objects you are sure about.

2. **Combine it with Protected Actions** - Protected Actions can require phishing-resistant MFA before someone permanently deletes an object. Hard Deletion Protection blocks the deletion during its window even when the user passes that check. Protected Actions needs Microsoft Entra ID P1 or P2.

3. **Monitor deletions** - Protection does not stop soft deletion. Alert on deletions of your critical objects so that you notice them within the seven days.

4. **Keep the list current** - Add new critical objects as you create them and review the list when staff or roles change.

## Learn More

- [Configure Hard Deletion Protection in Microsoft Entra (preview)](https://learn.microsoft.com/entra/backup/configure-hard-deletion-protection)
- [Microsoft Graph permissions reference: HardDeletionSetting.ReadWrite.Enable](https://learn.microsoft.com/graph/permissions-reference)
- [Hard Deletion Protection for Entra ID Directory Objects (Office 365 for IT Pros)](https://office365itpros.com/2026/11/09/hard-deletion-protection/)
- [Microsoft adds hard deletion protection for Entra ID (Our Cloud Network)](https://ourcloudnetwork.com/microsoft-adds-hard-deletion-protection-for-entra-id/)
- [Hard Deletion Protection in Microsoft Entra ID (HTMD)](https://www.anoopcnair.com/hard-deletion-protection-in-microsoft-entra-id/)
