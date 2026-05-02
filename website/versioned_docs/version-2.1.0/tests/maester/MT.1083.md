---
title: MT.1083 - Ensure Delicensing Resiliency is enabled
description: This test checks if Delicensing Resiliency is enabled in Exchange Online to maintain access when licenses are removed.
slug: /tests/MT.1083
sidebar_class_name: hidden
---

## Description

Delicensing Resiliency should be enabled to maintain access to mailboxes when licenses are removed, providing a grace period before access is lost. This helps prevent immediate disruption when licenses expire or are reassigned.

## Remediation action:

Enable Delicensing Resiliency by running the following PowerShell command in Exchange Online:

```powershell
Connect-ExchangeOnline
Set-OrganizationConfig -DelayedDelicensingEnabled:$true
```

### Optional: Configure User Notifications

You can also configure notifications to inform administrators and end users about delicensing events:

```powershell
# Enable tenant admin notifications for delicensing events
Set-OrganizationConfig -TenantAdminNotificationForDelayedDelicensingEnabled:$true

# Enable end user mail notifications for delicensing events
Set-OrganizationConfig -EndUserMailNotificationForDelayedDelicensingEnabled:$true
```

**Note**: These notification settings help ensure stakeholders are informed when licensing changes occur that could affect mailbox access.

## Related links

* [Delayed Delicensing in Exchange Online](https://learn.microsoft.com/en-us/Exchange/recipients-in-exchange-online/manage-user-mailboxes/exchange-online-delicensing-resiliency)
* [Set-OrganizationConfig](https://docs.microsoft.com/en-us/powershell/module/exchange/set-organizationconfig)
