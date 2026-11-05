---
title: Getting started
description: Your first Maester run, how to read the report, and how to go from a one-off check to continuous monitoring.
---

# Getting started

This page takes you from nothing to a first report in about fifteen minutes, then shows the steps most teams take
over the following weeks. Each step links to the full guide.

## Before you start

- **PowerShell 7.4 or later** on Windows, Linux or macOS.
- **An account that can read your tenant's configuration.** Global Reader is the usual choice. The first time
  you connect, an admin may need to consent to the Microsoft Graph permissions Maester asks for (see
  [Approval required when connecting](connect-maester/readme.md#approval-required-when-connecting)).

By default Maester asks only for read permissions. It does not change anything in your tenant.

## Step 1: Run your first report

```powershell
Install-Module Maester -Scope CurrentUser
Connect-Maester
Invoke-Maester
```

`Connect-Maester` connects to Microsoft Graph. That is enough for the Entra ID tests and most of the others. To
include Exchange Online, Teams, SharePoint and the other Microsoft 365 services, connect to all of them:

```powershell
Connect-Maester -Service All
Invoke-Maester
```

Tests for a service you have not connected to are reported as **Skipped**, with the reason, so you can tell which
results are missing and why. See [Installation](installation.mdx) and [Connect-Maester](connect-maester/readme.md).

## Step 2: Read the report

When the run finishes, Maester writes an HTML report to the `./test-results` folder and, in an interactive session, opens it. Every test appears with one
of these results:

| Result | What it means |
| --- | --- |
| **Passed** | The setting matches what the test expects. |
| **Failed** | The setting does not match. The test explains why and how to fix it. |
| **Investigate** | Maester found something a person should look at; it cannot decide on its own. |
| **Skipped** | The test did not run, for example because a service is not connected or a licence is missing. |
| **Error** | The test could not finish, for example because of a missing permission. |

Each failed test links to its own page on this site, with the background, the fix and the references.

## Step 3: Fix what matters first

A first report usually has many failures. Do not try to fix them all at once.

1. **Sort by severity.** Start with **Critical** and **High** (see [Severity levels](configuration/severity-levels.md)).
   To run only those tests:

   ```powershell
   Invoke-Maester -Severity Critical, High
   ```

2. **Look for quick wins.** Each test says how much its fix affects users and how much effort it takes. A failure
   with high severity, low user impact and low cost is the best place to start. In an interactive run, the
   **Fix first** panel lists these failures for you.
3. **Record what you accept.** Some failures are deliberate decisions. Turn those tests off in your configuration
   with a reason, so the report shows them as **Not run** with your reason instead of as failures (see the next
   step).

## Step 4: Tell Maester about your tenant

Create a folder for your Maester settings and a `maester-config.json` in it. The most important setting is your
emergency access (break glass) accounts, which many Conditional Access tests depend on:

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      { "Type": "User", "UserPrincipalName": "BreakGlass1@contoso.com" }
    ]
  },
  "TestSettings": [
    { "Id": "MT.1089", "Enabled": false, "Reason": "Accepted risk, see ticket SEC-123" }
  ]
}
```

Then run Maester from that folder, or pass it with `-Path`:

```powershell
Invoke-Maester -Path ./maester
```

See [Configure Maester](configuration/overview.md) and [Emergency access accounts](configuration/emergency-access-accounts.md).

## Step 5: Choose your baseline

Maester ships several suites: its own tests and the CIS, CISA, ASD Essential Eight, EIDSCA and ORCA suites. Pick the ones that match
the requirements your organisation has to meet. See [Choosing a baseline](choosing-a-baseline.md).

## Step 6: Monitor continuously

A single report shows where you stand today. The value of Maester comes from running it every day, so that a change
that weakens your security is caught within a day instead of at the next audit.

1. Run Maester on a schedule from a pipeline or an Azure service. See [Monitoring with Maester](monitoring/readme.mdx).
2. Send the results to the people who act on them by email, Teams or Slack. See [Maester alerts](alerts/readme.mdx).
3. Export results for a ticketing system or a spreadsheet. See [Exporting results](export-results.md).

## Step 7: Add your own tests

The built-in tests check widely recommended settings. Your organisation also has its own rules: a group that must
always be in a policy, a named location that must exist, an app that must never get more permissions. Write those
rules as [custom tests](writing-tests/index.mdx) and Maester checks them on every run alongside the built-in ones.

## Next steps

- Need support from leadership to roll this out? See [Making the case for Maester](making-the-case.mdx).
- Questions? See the [FAQ](faq.md).
