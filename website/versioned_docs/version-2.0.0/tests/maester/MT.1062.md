---
title: MT.1062 - Ensure Direct Send is set to be rejected
description: Checks if direct send is configured to reject in Exchange Online
slug: /tests/MT.1062
sidebar_class_name: hidden
---

# Ensure Direct Send is set to be rejected

## Description

> This test checks if the direct send feature in Exchange Online is configured to reject. Direct Send covers anonymous messages (unauthenticated messages) sent from your own domain to your organization's mailboxes using the tenant MX `xxx.mail.protection.outlook.com` (smarthost). Such traffic may include third-party services (applications, devices, or cloud providers) authorized to use your domain.
> Rationale: Attackers can exploit direct send to send spam or phishing emails without authentication.

## How to fix

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Configure the setting to reject direct send:
```powershell
Set-OrganizationConfig -RejectDirectSend $true
```

3. Verify the policy:
```powershell
(Get-OrganizationConfig).RejectDirectSend
```
The result should be `True`.

4. Anyone using the 'Direct Send' function will receive the following error message:
```
550 5.7.68 TenantInboundAttribution; Direct Send not allowed for this organization from unauthorized sources
```

## Known issues
There is a forwarding scenario that could be affected by this feature. It is possible that someone in your organization sends a message to a 3rd party and they in turn forward it to another mailbox in your organization. If the 3rd party’s email provider does not support Sender Rewriting Scheme (SRS), the message will return with the original sender’s address. Prior to this feature being enabled, those messages will already be punished by SPF failing but could still end up in inboxes. Enabling the Reject Direct Send feature without a partner mail flow connector being set up will lead to these messages being rejected outright.