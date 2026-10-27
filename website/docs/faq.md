---
sidebar_position: 7
title: ❓ FAQ
---

## Is this a Microsoft product?

No. Maester is an open-source, community led project and is not affiliated with Microsoft.

## How do I report issues?

If you encounter an issue with Maester, please [open an issue on GitHub](https://github.com/maester365/maester/issues).

## Previously installed 'Pester' version '3.4.0' conflicts with new module

If you see the following error when installing Maester, it means that you have an older version of Pester installed.

**A Microsoft-signed module named 'Pester' with version '3.4.0' that was previously installed conflicts with the new module 'Pester'**

Run the following command to install version 5.7.1 of Pester and then retry installing Maester.

```powershell
Install-Module Pester -MinimumVersion 5.7.1 -MaximumVersion 5.7.1 -Scope CurrentUser -SkipPublisherCheck -Force
```

To learn more or if you run into Pester installation issues see [Pester Installation and Update](https://pester.dev/docs/introduction/installation)

## Graph requests fail with a timeout error

If a test run fails with an error like `The request was canceled due to the configured HttpClient.Timeout of 300 seconds elapsing`, the Microsoft Graph SDK default timeout has been exceeded.

This is most common when using `-IncludeLongRunning` in tenants with a large number of objects.

When using `Connect-Maester`, pass the timeout to the Microsoft Graph connection:

```powershell
Connect-Maester -ClientTimeout 900
Invoke-Maester -IncludeLongRunning
```

If you connect to Microsoft Graph directly, set the timeout on `Connect-MgGraph` before running Maester:

```powershell
Connect-MgGraph -Scopes (Get-MtGraphScope) -ClientTimeout 900
Invoke-Maester -SkipGraphConnect -IncludeLongRunning
```

When `-ClientTimeout` is omitted, the Microsoft Graph PowerShell SDK default is used. The timeout applies to the Graph connection rather than to an individual test or request.

## Connect-Maester fails with "User canceled authentication" after an "Approval required" prompt

Global Reader and other non-admin accounts can't consent to the Microsoft Graph permissions that Maester requests. An admin needs to grant consent first. Approving the request from **Admin consent requests** in the Entra admin center can fail with `AADSTS70011: ... openid scope is required`.

See [Approval required when connecting](connect-maester/readme.md#approval-required-when-connecting) for how an admin can grant consent from PowerShell or set up a custom app registration.

## Connect-ExchangeOnline fails with "The role assigned to application ... isn't supported in this scenario"

The application signs in with certificate-based (app-only) authentication but has no role that Exchange Online accepts. Assign it **Security Reader** or **Global Reader** in Microsoft Entra ID, or the **View-Only Configuration** role in Exchange Online. If the connection works but the ORCA tests error with `The term 'Get-ProtectionAlert' is not recognized`, the application has an Exchange Online role but no Microsoft Entra role for Security & Compliance. Assign Security Reader or Global Reader. See [Roles for app-only access to Exchange Online and Security & Compliance](connect-maester/connect-maester-advanced.md#roles-for-app-only-access-to-exchange-online-and-security--compliance).
