---
title: Overview
sidebar_position: 1
---

# Configure Maester

Maester uses a configuration file called `maester-config.json` to customize how tests are run and to define global settings for your environment. This guide explains how the configuration system works and how to customize it for your organization.

## How Configuration Works

Maester uses a two-tier configuration system:

1. **Main Configuration** (`./tests/maester-config.json`) - Contains the default settings for all Maester tests. This file is maintained by the Maester team and is updated when you run `Update-MaesterTests`.

2. **Custom Configuration** (`./tests/Custom/maester-config.json`) - Your organization-specific overrides. Settings in this file take precedence over the main configuration.

:::warning Important
Never edit the main `maester-config.json` file in the `./tests` folder directly. Your changes will be overwritten when you update Maester tests.

Always use the `./tests/Custom/maester-config.json` file for your customizations.
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

The `TestSettings` section allows you to customize individual test behavior, such as overriding the default severity level. See [Severity Levels](./severity-levels) for more details.

## Creating Your Custom Configuration

To create your custom configuration file:

1. Navigate to your Maester tests folder
2. Create a file called `maester-config.json` in the `Custom` folder
3. Add your custom settings

```bash
# Create the custom config file
./tests/Custom/maester-config.json
```

Here's a complete example of a custom configuration file:

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

## How Settings Are Merged

When Maester loads the configuration:

1. It first loads the main `maester-config.json` from the `./tests` folder
2. Then it looks for `./tests/Custom/maester-config.json`
3. Any settings in the custom file **override** the corresponding settings in the main file
4. New settings in the custom file are **added** to the configuration

This means you only need to include the settings you want to change or add in your custom configuration file.

## Validating Your Configuration

After creating or modifying your configuration file, you can verify it's being loaded correctly by running Maester with verbose output:

```powershell
Invoke-Maester -Verbose
```

Look for messages indicating your custom configuration was found and merged.
