---
title: Merging Results
sidebar_label: Merging Results
sidebar_position: 2
---

# Merging Results

To create a multi-tenant report, run Maester against each tenant separately, save the JSON output, and merge them with `Merge-MtMaesterResult`.

## PowerShell example

```powershell
# Run Maester against three tenants and save JSON results
Connect-MgGraph -TenantId $tenantProduction
Invoke-Maester -PassThru -OutputJsonFile ./production.json
Disconnect-MgGraph

Connect-MgGraph -TenantId $tenantDevelopment
Invoke-Maester -PassThru -OutputJsonFile ./development.json
Disconnect-MgGraph

Connect-MgGraph -TenantId $tenantChina -Environment China
Invoke-Maester -PassThru -OutputJsonFile ./china.json
Disconnect-MgGraph

# Generate the multi-tenant HTML report
Merge-MtMaesterResult -Path *.json | Get-MtHtmlReport | Out-File ./MultiTenantReport.html
```

`Merge-MtMaesterResult -Path` loads the JSON files, validates them, and merges them into a single multi-tenant result — no manual file loading needed.

:::tip Alternative: use a directory or explicit file paths
```powershell
# From a directory (auto-discovers TestResults-*.json, falls back to *.json)
Merge-MtMaesterResult -Path ./results/ | Get-MtHtmlReport | Out-File ./report.html

# Explicit file list
Merge-MtMaesterResult -Path ./production.json, ./development.json, ./china.json |
    Get-MtHtmlReport | Out-File ./report.html
```
:::

## Step by step

1. **Connect and run** - For each tenant, connect using `Connect-MgGraph` with the tenant ID (and `-Environment` for national clouds), then run `Invoke-Maester` with `-OutputJsonFile` to save the results as JSON.

2. **Merge and report** - Pass the file paths (or a directory/glob) to `Merge-MtMaesterResult -Path`. It loads each JSON file, validates the result structure, and creates a single object with a `Tenants` array. Pipe it into `Get-MtHtmlReport` to generate the report.

The report automatically detects the multi-tenant format and renders the tenant selector in the sidebar.

## Loading results separately with Import-MtMaesterResult

If you need more control, use `Import-MtMaesterResult` to load the files first, then pipe them into `Merge-MtMaesterResult`:

```powershell
Import-MtMaesterResult -Path *.json | Merge-MtMaesterResult | Get-MtHtmlReport | Out-File ./report.html
```

`Import-MtMaesterResult` returns an array of individual result objects. It also auto-expands multi-tenant merged JSON files (files with a `Tenants` array) back into individual results, so you can re-process previously merged outputs.

## National clouds

When connecting to tenants in national clouds, pass the `-Environment` parameter to `Connect-MgGraph`:

| Environment | Cloud |
| --- | --- |
| `Global` | Microsoft Azure Commercial (default) |
| `China` | Microsoft Azure China (21Vianet) |
| `USGov` | Microsoft Azure US Government (GCC High) |
| `USGovDoD` | Microsoft Azure US Government DoD |
| `Germany` | Microsoft Azure Germany |
