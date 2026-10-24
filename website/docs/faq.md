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

`Invoke-Maester` sends two anonymous events to `packs.maester.cloud`, a service run by the Maester maintainers on
Cloudflare: one when the run starts and one when it ends, even when it stops early, fails or is cancelled. Together
they show the maintainers when a new release starts to fail. They hold:

- a random run ID, and a random installation ID kept in `~/.maester/installation-id` (delete the file to get a new
  one);
- a SHA-256 hash of the tenant ID, never the tenant ID itself;
- the Maester and PowerShell versions, the operating system and its version, and the CI system if the run is in one;
- when the run started, how long it took, and whether it completed. For a run that did not, how far it got and the
  type of the error, never the error message;
- how many tests passed, failed, errored, were skipped or did not run, never which tests or what they found;
- the [Maester Packs](./packs/index.md) installed and the packs that ran, with their versions and test counts, but
  only packs from public repositories and packs that ship with Maester. A pack from a private repository or a local
  folder is never sent.

The service looks up the country and region the request came from, and does not store the IP address.

`Install-MtPack` sends a similar event when it installs a pack from a public repository. That's how the
[packs site](https://packs.maester.cloud) counts installs and finds new packs.

No test names, results of a check, email addresses or tenant content (users, policies, findings) are sent; the
tenant is identified only by the hash of its ID described above. A pack's page shows its own usage counts. Daily
totals that hold an installation ID or a tenant hash are deleted after 400 days.

While the new service is being proven, `Invoke-Maester` also sends the single event it has always sent to PostHog
when a run starts, which holds the tenant ID. That event will be removed.

To turn telemetry off, use `Invoke-Maester -DisableTelemetry`, or set the environment variable
`MAESTER_DISABLE_TELEMETRY` to `1`, which covers every command.
