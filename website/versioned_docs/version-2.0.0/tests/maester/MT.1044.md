---
title: MT.1044 - Ensure modern authentication for Exchange Online is enabled
description: Checks if modern authentication in Microsoft 365 is enabled. Modern authentication enables authentication features like multifactor authentication (MFA) using smart cards, certificate-based authentication (CBA), and third-party SAML identity providers.
slug: /tests/MT.1044
sidebar_class_name: hidden
---

# Ensure modern authentication for Exchange Online is enabled

## Description

> Modern authentication in Microsoft 365 enables authentication features like multifactor authentication (MFA) using smart cards, certificate-based authentication (CBA), and third-party SAML identity providers. When you enable modern authentication in Exchange Online, Outlook 2016 and Outlook 2013 use modern authentication to log in 'to Microsoft 365 mailboxes. When you disable modern authentication in Exchange Online, Outlook 2016 and Outlook 2013 use basic authentication to log in to Microsoft 365 mailboxes.
> When users initially configure certain email clients, like Outlook 2013 and Outlook 2016, they may be required to authenticate using enhanced authentication mechanisms, such as multifactor authentication. Other Outlook clients that are available in Microsoft 365 (for example, Outlook Mobile and Outlook for Mac 2016) always use modern uthentication to log in to Microsoft 365 mailboxes

## How to fix

> 1. Open Powershell and connect to Exchange Online: `Connect-ExchangeOnline`
> 2. Run the following PowerShell command: `Set-OrganizationConfig -OAuth2ClientProfileEnabled $True`
