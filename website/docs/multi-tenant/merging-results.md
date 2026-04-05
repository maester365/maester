---
title: Merging Results
sidebar_label: Merging Results
sidebar_position: 2
---

# Merging Results

To create a multi-tenant report, run Maester against each tenant separately, collect the JSON output, and merge them into a single result using `Merge-MtMaesterResult`.

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

# Load results and merge
$allResults = @()
Get-ChildItem -Path . -Filter '*.json' | ForEach-Object {
    $allResults += Get-Content $_.FullName -Raw | ConvertFrom-Json
}
$merged = Merge-MtMaesterResult -MaesterResults $allResults

# Generate the multi-tenant HTML report
Get-MtHtmlReport -MaesterResults $merged | Out-File ./MultiTenantReport.html -Encoding UTF8
```

## Step by step

1. **Connect and run** - For each tenant, connect using `Connect-MgGraph` with the tenant ID (and `-Environment` for national clouds), then run `Invoke-Maester` with `-OutputJsonFile` to save the results as JSON.

2. **Load the JSON files** - Read all result files back into PowerShell objects. Each file contains the full Maester result for one tenant.

3. **Merge** - Pass the array of results to `Merge-MtMaesterResult`. This creates a single object with a `Tenants` array where each entry contains the tenant's display name, ID, and test results.

4. **Generate the report** - Pass the merged object to `Get-MtHtmlReport`. The report automatically detects the multi-tenant format and renders the tenant selector in the sidebar.

## National clouds

When connecting to tenants in national clouds, pass the `-Environment` parameter to `Connect-MgGraph`:

| Environment | Cloud |
| --- | --- |
| `Global` | Microsoft Azure Commercial (default) |
| `China` | Microsoft Azure China (21Vianet) |
| `USGov` | Microsoft Azure US Government (GCC High) |
| `USGovDoD` | Microsoft Azure US Government DoD |
| `Germany` | Microsoft Azure Germany |
