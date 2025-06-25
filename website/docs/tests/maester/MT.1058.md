---
title: MT.1058 - Exchange Application Access Policies should be configured
description: Checks if applications with Exchange permissions have application access policies configured
slug: /tests/MT.1058
sidebar_class_name: hidden
---

# Exchange Application Access Policies should be configured

## Description

Applications that use Microsoft Graph API permissions for Exchange Online (Mail, Calendar, Contacts) can access all mailboxes in your organization by default. This presents a significant security risk as a compromised application could access sensitive data across all mailboxes.

Application access policies help mitigate this risk by:
- Restricting which mailboxes an application can access
- Limiting the scope of potential data breaches
- Enforcing the principle of least privilege

The following Microsoft Graph permissions require application access policies:

**Mail Access:**
- Mail.Read
- Mail.ReadBasic
- Mail.ReadBasic.All
- Mail.ReadWrite
- Mail.Send

**Mailbox Settings:**
- MailboxSettings.Read
- MailboxSettings.ReadWrite

**Calendar Access:**
- Calendars.Read
- Calendars.ReadWrite

**Contacts Access:**
- Contacts.Read
- Contacts.ReadWrite

**Note: Only the listed permissions are restricted by the application access policy.**

## How to fix

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Define variables for your application:
```powershell
# Get these values from your Application Registration
$AppID = "<your-app-id>"  # e.g. "0a3ad682-b031-416d-86c2-bf263f8b46a3"
$GroupName = "AAP_$AppID"  # example naming convention for clarity
$Description = "Restrict this app to members of distribution group"
```

3. Create a mail-enabled security group for policy scope:
```powershell
# Create group and hide from address list
$DGroup = New-DistributionGroup -Name $GroupName -Type Security
Start-Sleep -Seconds 5  # Wait for group creation to propagate
Set-DistributionGroup -Identity $DGroup.WindowsEmailAddress -HiddenFromAddressListsEnabled $true
```

4. Create the application access policy:
```powershell
New-ApplicationAccessPolicy -AppId $AppID `
                          -PolicyScopeGroupId $DGroup.WindowsEmailAddress `
                          -AccessRight RestrictAccess `
                          -Description $Description
```

5. Add members to the security group:
```powershell
Add-DistributionGroupMember -Identity $GroupName -Member user@contoso.com
```

6. Verify the policy:
```powershell
# List all policies
Get-ApplicationAccessPolicy

# Test for specific user
Test-ApplicationAccessPolicy -Identity user@contoso.com -AppId $AppID
```

## Learn more

* [Control application access to Exchange Online mailboxes](https://learn.microsoft.com/graph/auth-limit-mailbox-access)
* [New-ApplicationAccessPolicy](https://learn.microsoft.com/powershell/module/exchange/new-applicationaccesspolicy)
* [Test-ApplicationAccessPolicy](https://learn.microsoft.com/powershell/module/exchange/test-applicationaccesspolicy)