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

Increase the timeout via the `-GraphRequestTimeoutSeconds` parameter:

```powershell
Invoke-Maester -IncludeLongRunning -GraphRequestTimeoutSeconds 900
```

Or set it persistently in `./tests/Custom/maester-config.json`:

```json
{
  "GlobalSettings": {
    "GraphRequestTimeoutSeconds": 900
  }
}
```

See [Configuration Overview](./configuration/overview) for more details on the configuration file.

When neither override is provided, Maester leaves the existing Microsoft Graph SDK request context unchanged.
