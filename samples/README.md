# Multi-Tenant Report Samples

This folder contains sample HTML reports and a generator script for reviewing the multi-tenant report feature.

## Files

| File | Description |
| --- | --- |
| `generate-samples.ps1` | PowerShell script that generates the sample reports |
| `sample-report-single-tenant.html` | Single-tenant report with 12 tests |
| `sample-report-multi-tenant.html` | Multi-tenant report with 3 tenants |

## Generate Reports

Run from this folder:

```powershell
cd samples
pwsh -File ./generate-samples.ps1
```

## Multi-Tenancy Changes

### Overview

This feature adds support for running Maester tests across multiple tenants and viewing all results in a single HTML report with a tenant selector sidebar.

### PowerShell Changes

#### `powershell/public/core/Merge-MtMaesterResult.ps1` (new)

Merges multiple `Invoke-Maester -PassThru` results into a single object with a `Tenants` array. Preserves `CurrentVersion` and `LatestVersion` from the first result. Always wraps in a `Tenants` array, even for a single tenant.

#### `powershell/public/core/Get-MtHtmlReport.ps1` (updated)

Now supports both single-tenant and multi-tenant result objects. Detects multi-tenant format by checking for a `Tenants` property and increases JSON serialization depth from 5 to 7 to handle the extra nesting level.

#### `powershell/internal/Get-MtMaesterConfig.ps1` (updated)

Added `-TenantId` parameter for tenant-specific configuration. When provided and is a valid GUID, the function looks for `maester-config.{TenantId}.json` first and falls back to `maester-config.json` if not found. Invalid TenantId values (not a GUID) are ignored. The loaded config file name is stored in a `ConfigSource` property so the report UI can show which config was used (multi-tenant reports only).

**Config file resolution order:**
1. `maester-config.{TenantId}.json` (if `-TenantId` is a valid GUID and file exists)
2. `maester-config.json` (default fallback)
3. `Custom/maester-config.json` (merged on top, existing behavior)

**Single-tenant users are not affected** — without `-TenantId` (or when not connected to Graph), the function behaves identically to before.

**Example folder structure:**
```
tests/
  maester-config.json                                          # shared default
  maester-config.a1b2c3d4-e5f6-7890-abcd-ef1234567890.json    # Contoso Production
  maester-config.b2c3d4e5-f6a7-8901-bcde-f12345678901.json    # Fabrikam Development
```

#### `powershell/public/Invoke-Maester.ps1` (updated)

Now resolves the connected tenant ID from `Get-MgContext` and passes it to `Get-MtMaesterConfig`, enabling automatic tenant-specific config file selection.

### React / Report UI Changes

#### `report/src/context/TenantContext.tsx` (new)

React context that manages tenant selection state. Normalizes both single-tenant and multi-tenant data formats into a consistent `Tenants` array. Provides `selectedTenant`, `tenants`, and `setSelectedIndex` to all pages.

#### `report/src/components/Sidebar.tsx` (updated)

Shows a **Tenants** section in the sidebar when multiple tenants are present. Each tenant is clickable to switch the dashboard. The tenant selector is hidden for single-tenant reports.

#### `report/src/pages/ConfigPage.tsx` (updated)

- Displays which config file was loaded via the `ConfigSource` property (e.g., "Loaded from: maester-config.a1b2c3d4.json") — only shown for multi-tenant reports
- Resets state when switching tenants to prevent data leak between tenants (`useEffect` on `originalConfig`)

#### Other pages (updated)

All pages (`HomePage`, `ExcelPage`, `MarkdownPage`, `PrintPage`, `SettingsPage`, `SystemPage`) now read data from `useTenant()` context instead of the global `testResults`, ensuring they display the selected tenant's data.

### Pipeline Changes

#### `powershell/examples/multi-tenant-pipeline.yml` (new)

Azure DevOps pipeline example that:
1. Installs modules once
2. Runs Maester tests per tenant using `${{ each }}` loop with separate service connections
3. Merges all JSON results with `Merge-MtMaesterResult`
4. Generates a combined HTML report
5. Publishes to an Azure Web App

Supports Global, China, USGov, USGovDoD, and Germany cloud environments with automatic endpoint resolution.

### Pester Tests

#### `powershell/tests/functions/Merge-MtMaesterResult.Tests.ps1` (new)

Tests for the merge function: empty input throws, single tenant wraps, two tenants merge, three tenants merge, metadata preservation, missing Tests property throws, empty TenantName handled.

#### `powershell/tests/functions/Get-MtHtmlReport.Tests.ps1` (new)

Tests for HTML report generation: valid HTML output, tenant names present, sample data replaced, compressed JSON, template availability skip guard.
