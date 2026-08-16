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
