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

## What telemetry does Maester send?

At the end of each run, `Invoke-Maester` sends one anonymous event to `packs.maester.cloud`, a service run by the
Maester maintainers on Cloudflare. It holds:

- a random installation ID, kept in `~/.maester/installation-id` (delete the file to get a new one);
- a SHA-256 hash of the tenant ID, never the tenant ID itself;
- the Maester version, the operating system, and the CI system if the run is in one;
- the number of tests that ran;
- each [Maester Pack](./packs/index.md) that ran, with its version and test count, but only packs from public
  repositories and packs that ship with Maester. A pack from a private repository or a local folder is never sent.

`Install-MtPack` sends a similar event when it installs a pack from a public repository. That's how the
[packs site](https://packs.maester.cloud) counts installs and finds new packs.

No test results, names, email addresses or tenant data are sent. Maintainers see totals for each day, and a pack's
page shows its own usage counts. Rows that hold an installation ID or a tenant hash are deleted after 400 days.

To turn telemetry off, use `Invoke-Maester -DisableTelemetry`, or set the environment variable
`MAESTER_DISABLE_TELEMETRY` to `1`, which covers every command.
