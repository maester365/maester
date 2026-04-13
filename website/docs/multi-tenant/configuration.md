---
title: Tenant-specific Configuration
sidebar_label: Configuration
sidebar_position: 3
---

# Tenant-specific Configuration

Each tenant can have its own `maester-config.json` by naming it with the tenant ID. This allows different emergency access accounts and severity overrides per tenant while sharing a common baseline.

## How it works

When Maester runs, it automatically detects the connected tenant ID and looks for `maester-config.{tenantId}.json` first. If no tenant-specific file exists, it falls back to `maester-config.json`.

## Example

```
tests/
  maester-config.json                                          # shared default
  maester-config.a1b2c3d4-e5f6-7890-abcd-ef1234567890.json    # Contoso Production
  maester-config.b2c3d4e5-f6a7-8901-bcde-f12345678901.json    # Fabrikam Development
```

In this example Contoso Production uses its own config with tenant-specific emergency access accounts, Fabrikam Development has different severity overrides, and any other tenant falls back to the shared `maester-config.json`.

## Config page in the report

In multi-tenant reports, the Config page shows which config file was loaded for each tenant so you can verify the right file is being used.

## Single-tenant users

Single-tenant users are not affected. Everything works exactly as before with the default `maester-config.json`. The tenant-specific lookup only activates when a file matching the pattern exists.

For more details on the configuration system, see [Configure Maester](/docs/configuration/overview).
