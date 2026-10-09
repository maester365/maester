---
title: Overview
sidebar_position: 1
---

# Configure Maester

Maester uses a configuration file called `maester-config.json` to customize how tests are run and to define global settings for your environment. This guide explains the basics; the [run configuration reference](./run-configuration.md) lists every section and key.

## How Configuration Works

From Maester 3.0 the tests carry their own defaults (severity, parameters), and the module no longer ships a configuration file with a row per test. Your configuration only holds what you want to change.

Maester reads these files from the folder you pass with `-Path` (or the current folder), each one optional:

1. **`maester-config.json`** - your main configuration. Maester looks in `-Path`, `-Path/tests` and up to five parent folders.
2. **`custom/maester-config.json`** - an overlay on the main file, for example settings owned by a different team.
3. **`maester-config.<tenantId>.json`** - settings for one tenant, merged over the other two once Maester knows which tenant you are connected to.

Each file merges over the one before, so a tenant file only needs the values that differ for that tenant.

Instead of files next to your tests, you can pass a configuration with `Invoke-Maester -Config` (a path, an object, or several merged left to right) or the `MAESTER_CONFIG` environment variable. Then the files next to your tests are not read.

:::note Upgrading from 2.x
In 2.x the main `./tests/maester-config.json` was maintained by the Maester team and overwritten by `Update-MaesterTests`, so your changes had to go into `./tests/Custom/maester-config.json`. Both files keep working in 3.0. A copy of the old shipped file still overrides every test's severity; keep only the rows you changed. A tenant file is now merged over the main file instead of replacing it. See [Upgrading from 2.x](../upgrading-from-2x.md#configuration).
:::

## Configuration File Structure

The configuration file has two main sections:

```json
{
  "GlobalSettings": {
    // Organization-wide settings that apply to multiple tests
  },
  "TestSettings": [
    // Test-specific settings like severity levels
  ]
}
```

### GlobalSettings

The `GlobalSettings` section contains organization-wide configuration that can be used by multiple tests. For example, you can define your emergency access accounts here so that all related tests use the same accounts.

### XSPM external data sources

The XSPM unified identity query uses Advanced Hunting `externaldata` sources to enrich identity results. You can override these sources with HTTPS mirrors by adding `XspmExternalDataUris` to the `GlobalSettings` section of your custom configuration:

```json
{
  "GlobalSettings": {
    "XspmExternalDataUris": {
      "EntraDirectoryRoles": "https://mirror.contoso.com/Classification_EntraIdDirectoryRoles.json",
      "MicrosoftApps": "https://mirror.contoso.com/MicrosoftApps.json",
      "ApiPermissions": "https://mirror.contoso.com/Classification_ApiPermissions.json",
      "ArmApiRequests": "https://mirror.contoso.com/ArmApiRequest.csv"
    }
  }
}
```

All values must be absolute HTTPS URIs. Because `externaldata` is evaluated by Defender Advanced Hunting, the mirror must be reachable by that service, not only by the computer running Maester. See Microsoft's [Advanced Hunting best practices](https://learn.microsoft.com/en-us/microsoft-365/security/defender/advanced-hunting-best-practices) for details.

Omitted keys retain their built-in defaults. A mirror must preserve the original JSON or CSV schema. Use an immutable commit URL or a versioned mirror object when reproducible classification is required; the default URLs still track upstream branches. User information and fragments in URIs are rejected. Signed query strings are supported, but treat the configuration file as a secret and grant only read access to the mirrored data. Maester suppresses verbose configuration/query logging on this path and redacts configured query strings in its diagnostic message. This does not control logging by the service or by external instrumentation.

### TestSettings

The `TestSettings` section changes individual tests by ID: severity, turning a test off, parameter values and timeouts.

```json
{
  "TestSettings": [
    { "Id": "MT.1005", "Severity": "Critical" },
    { "Id": "MT.1089", "Enabled": false, "Reason": "Not relevant for this tenant" },
    { "Id": "MT.1198", "Parameters": { "MaximumValidityDays": 180 } }
  ]
}
```

A disabled test is not run and appears in the report as **Not run** with the reason you gave. See [Severity Levels](./severity-levels) and the [run configuration reference](./run-configuration.md#testsettings).

### Other sections

`Selection` (which tests run), `Environment` (facts about the tenant and which applicability checks are enforced), `Execution` (timeouts), `Output` (CI test result files) and `Metadata` (labels echoed in the results) are described in the [run configuration reference](./run-configuration.md).

## Creating Your Configuration

If you ran `Install-MaesterTests`, your folder already has a starter `maester-config.json`. Otherwise create one in the folder you run Maester from. Here's a complete example:

```json
{
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      {
        "UserPrincipalName": "BreakGlass1@contoso.com",
        "Type": "User"
      },
      {
        "Id": "00000000-0000-0000-0000-000000000000",
        "Type": "Group"
      }
    ]
  },
  "TestSettings": [
    {
      "Id": "MT.1005",
      "Severity": "Critical"
    }
  ]
}
```

## Available Global Settings

The following global settings are available for customization:

| Setting | Description | Documentation |
|---------|-------------|---------------|
| `EmergencyAccessAccounts` | Define your break glass accounts and groups | [Emergency Access Accounts](./emergency-access-accounts.md) |
| `XspmExternalDataUris` | Override the HTTPS sources used by XSPM Advanced Hunting queries | This page |

The GitHub and Dataverse settings are listed in the [run configuration reference](./run-configuration.md#globalsettings).

## How Settings Are Merged

When several files are found, each one merges over the one before:

- `TestSettings` rows are matched by `Id`, and each property you set replaces the same property in the lower file.
- Other sections are merged key by key.
- Lists replace lists: an empty list in a higher file clears the lower one.

This means you only need to include the settings you want to change or add.

## Validating Your Configuration

Run Maester without running any test to see which configuration it used and what it would do:

```powershell
$plan = Invoke-Maester -DryRun -PassThru
$plan.MaesterConfig.ConfigSource      # the files that were read
$plan.Tests | Group-Object Result, ReasonCode
```

See [Applicability and reason codes](./applicability.md) for what each reason means.
