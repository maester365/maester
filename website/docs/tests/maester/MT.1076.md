---
title: MT.1076 - MOERA SHOULD NOT be used for sent mail.
description: This test checks if MOERA addresses are sending email.
slug: /tests/MT.1076
sidebar_class_name: hidden
---

## Description

Microsoft Online Exchange Routing Addresses (MOERA) SHOULD NOT be used for sent mail.

## Remediation action:

For each listed user principal name, update primary SMTP address to use a [registered domain](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomDomainNames).

> If the listed user principal name sends mail from a script or application, you may need to update that configuration as well.

### Entra Managed Mail Attributes

1. Within the [Microsoft Entra admin center](https://entra.microsoft.com), navigate to [All users](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/AllUsers/menuId/).
2. Select the user.
3. Select **Edit properties**.
4. Select **Contact information**.
5. Update the **Email** attribute.
6. Select **Save**.

### AD Managed Mail Attributes

Processes can vary depending on use of PowerShell, AD MMCs, or Exchange Management Portal. Update according to your internal processes.

## Related links

* [Limiting Onmicrosoft Domain Usage for Sending Emails](https://techcommunity.microsoft.com/blog/exchange/limiting-onmicrosoft-domain-usage-for-sending-emails/4446167)
