---
title: Upgrading from 2.x
sidebar_label: ⬆️ Upgrading from 2.x
description: What changes when you move from Maester 2.x to 3.0, and what to do about each change.
---

# Upgrading from Maester 2.x to 3.0

Maester 3.0 gives Maester its own test engine. The built-in tests are no longer Pester files that you copy into a
folder: they ship inside the module and run from there. Most runs need no change at all, but the way tests are
installed, selected, configured and written has moved on. This page lists every change that can affect you.

## Checklist

1. Run Maester on **PowerShell 7.4 or later**. Windows PowerShell 5.1 is no longer supported.
2. Update the module, and remove Maester 2.x from the machine:

   ```powershell
   Update-Module Maester -Force
   Uninstall-Module Maester -MaximumVersion 2.99.99 -AllVersions
   ```

   Start a new PowerShell session afterwards.
3. Clean up your tests folder: `Update-MaesterTests -Path ./maester-tests -WhatIf`, then without `-WhatIf`.
4. If you disabled built-in tests by deleting their files, disable them in `maester-config.json` instead.
5. If you have Pester-format custom tests, install Pester 5.7.1 or later yourself, or convert the tests with
   `Convert-MtTest`.
6. If a custom test calls a built-in `Test-Mt*` function, replace the call with `Invoke-MtTest -Id <ID>`.
7. If you read the result JSON or XML, review the [result changes](#result-changes).
8. Try your usual command with `-DryRun -PassThru` first to see what would run.

## Requirements

- **PowerShell 7.4 or later** (the `Core` edition) on Windows, Linux or macOS. The module no longer loads in
  Windows PowerShell 5.1.
- **Pester is optional.** Maester no longer depends on Pester or installs it. You need Pester 5.7.1 or later only
  if you run [Pester-format custom tests](./writing-tests/pester-format-tests.md), or if your scripts call
  `New-PesterConfiguration`. Without Pester, a run with Pester-format tests reports them as `Error` rows with
  reason `PesterNotAvailable` and still runs everything else.
- **Remove Maester 2.x.** `Update-Module` keeps the old version installed. When a script calls a function that
  only 2.x exports, PowerShell loads 2.x into the session and from then on `Invoke-Maester` is the 2.x one.
  Maester 3.0 warns when 2.x is installed, and if 2.x gets loaded during a run it removes it again and marks the
  affected row `Error` with reason `ForeignModuleLoaded`. After updating, start a new session: a loaded module
  cannot be replaced in a running process.

## The built-in tests run from the module

In 2.x, `Install-MaesterTests` copied the tests into a folder and `Update-MaesterTests` refreshed the copies. In
3.0 the tests ship in the module, so **updating the module updates the tests**. Your folder now holds only your
own tests and your configuration.

- **The built-in tests always run.** `-Path` is now "where my custom tests and config live". Commands documented
  for 2.x, such as `Invoke-Maester -Path ./tests/Maester` or `Invoke-Maester ./tests/Custom`, now run every
  built-in test plus the custom tests under that path. To run only your custom tests, add `-SkipBuiltIn` (or set
  `Selection.BuiltIn` to `None`). To run only some built-in tests, use `-Tag` or `-TestId`.
- **A run needs no test folder.** Without `-Path`, Maester looks for custom tests in the current folder only when
  it looks like a Maester folder (a `maester-config*.json` file, a `Custom` folder, a 2.x suite folder, or a test
  file). Otherwise it runs the built-in tests and tells you to pass `-Path` for custom tests.
- **A `-Path` that does not exist** is a warning, not an error: the built-in tests still run and the config is
  looked up from the nearest existing parent folder. With `-SkipBuiltIn` it stays an error.
- **Deleting a test file no longer disables a test.** The built-in tests come back. Disable a test in the
  config instead:

  ```json
  { "TestSettings": [ { "Id": "MT.1005", "Enabled": false, "Reason": "Handled by another control" } ] }
  ```

- **Stale copies are not run.** A 2.x copy of a built-in test (identified by its ID, a previous ID, the ID of a
  retired test, or a family prefix such as `MT.1024.`) is skipped wherever it is, including under `Custom/`. It
  produces no row; Maester warns once, names the files, and lists them under `Selection.Superseded` in the result.
- **Copying a built-in test into `Custom/` to change it no longer works.** Change its severity or parameters in
  the config, or copy it under your own ID and disable the built-in.

### Install-MaesterTests and Update-MaesterTests

| Command | 2.x | 3.0 |
| --- | --- | --- |
| [`Install-MaesterTests`](./commands/Install-MaesterTests.mdx) | Copied every test into the folder and installed Pester. | Writes `Custom/README.md` and a starter `maester-config.json` when they are missing. Never writes a test file and never overwrites a file, so pipelines can keep calling it on every run. Does not install Pester; `-SkipPesterCheck` has no effect. |
| [`Update-MaesterTests`](./commands/Update-MaesterTests.mdx) | Overwrote the test folders with the latest tests. | Removes the 2.x copies of built-in tests: every `*.Tests.ps1` outside `Custom/` whose tests all have a current, previous or retired built-in ID, and the folders that leaves empty. Keeps files that also hold tests of your own (with a warning), and never touches `Custom/`. Asks for confirmation unless you pass `-Force`; supports `-WhatIf`. It also reduces a copy of the 2.x shipped `maester-config.json` to the rows that differ from the built-in severities or set something else. |

Pipelines that clone a copy of the 2.x tests and pass its folder to `-Path` keep working: the copies are
recognised and skipped, and the built-in tests run from the module.

## Configuration

The `maester-config.json` format is the same, with new sections. See the
[run configuration reference](./configuration/run-configuration.md).

- **The shipped rows are gone.** The module no longer ships a `maester-config.json` with a row per test: each
  test now carries its default severity. Your config needs only the rows you change. A copy of the 2.x shipped
  file in your folder (300 or more rows with `Title`) still overrides every severity; Maester warns about it.
  `Update-MaesterTests` reduces it to the rows you changed, or delete the others yourself.
- **Severity comes from the test.** The order is: a `TestSettings` row in your config, then the test's
  `Severity`, then (for tests that compute it at run time) the severity the test reports. `Severity:<level>`
  tags apply only to Pester-format tests.
- **`TestSettings` rows do more.** Besides `Severity`, a row can set `Enabled`, `Reason`, `Parameters` and
  `TimeoutSeconds`, for any test ID. In 2.x only `Severity` was applied, and a row in `Custom/maester-config.json`
  worked only if the main file had a row for the same ID.
- **The tenant file is merged.** `maester-config.<tenantId>.json` used to replace `maester-config.json`; now it
  merges over it (and over `Custom/maester-config.json`), so a tenant inherits base settings it does not set. A
  tenant file that relied on hiding a base value must set it explicitly. Maester warns once and names the
  inherited settings.
- **`Custom/maester-config.json` works without a root file.**
- **New ways to supply config**: `-Config <path | object | array>` and the `MAESTER_CONFIG` environment variable.
  Both make the run hermetic: config files next to the tests are not read.

## Selecting tests

New `Invoke-Maester` parameters:

| Parameter | Effect |
| --- | --- |
| `-TestId` | Run only these test IDs. Exact IDs or `*` wildcards, case-insensitive. A test named by its exact ID runs even if it is preview or long-running. |
| `-ExcludeTestId` | Do not run these IDs. Wins over `-TestId`. |
| `-Config` | The run configuration, instead of the files next to the tests. |
| `-DryRun` | Work out what would run, and why the rest would not, without running any test. Each test that would have run is `NotRun` with reason `DryRun`. |
| `-SkipBuiltIn` | Run only the custom tests under `-Path`. |

Every existing parameter stays. Changed behaviour:

- **`-Tag All` and `-Tag Full` are removed.** They were deprecated in 2.x and selected nothing, because no
  test carries those tags. Using them now stops the run with an error: use `-IncludePreview` instead of
  `All` and `-IncludeLongRunning` instead of `Full`.
- **`-PesterConfiguration`** accepts a `[PesterConfiguration]` object or a hashtable, and its `Run.Path`,
  `Filter.Tag`, `Filter.ExcludeTag` and `TestResult` options apply to native tests too. Its `Filter.ExcludeTag`
  is now added to the default exclusions; 2.x discarded it whenever Preview or long-running tests were excluded
  by default, so those tests ran. See [Pester-format tests](./writing-tests/pester-format-tests.md#-pesterconfiguration).
- **Deselected tests carry a reason.** `NotRun` rows say why: not selected, excluded by tag or ID, disabled,
  preview, long-running, Active Directory not connected. See
  [Applicability and reason codes](./configuration/applicability.md).
- **`-Verbosity Normal`** prints one line per finished test, and `Detailed` also a line when each test starts.

## Exported commands

Maester 2.x exported about 730 commands, most of them the check functions behind each test (`Test-MtCa...`,
`Test-MtCisa...`, `Test-MtEidsca...`). Maester 3.0 exports 67. The check functions still exist inside the module,
but they are no longer exported and no longer check their own connections or catch their own errors: the engine
does that.

- To run a built-in check from a script or from a custom test, use `Invoke-MtTest -Id <ID>`. It runs the check
  through the engine, with its connection and licence checks, and returns the result row.

  ```powershell
  # 2.x
  $ok = Test-MtCaMfaForRiskySignIn
  # 3.0
  $ok = (Invoke-MtTest -Id MT.1012).Result -eq 'Passed'
  ```

- `Test-MtConnection` and `Test-MtConditionalAccessWhatIf` stay exported with the same parameters.
- The supporting commands (`Connect-Maester`, `Invoke-MtGraphRequest`, `Add-MtTestResultDetail`,
  `Get-MtLicenseInformation`, `Get-MtConditionalAccessPolicy`, the report and export commands, and so on) stay.
- New commands: `Invoke-MtTest`, `Get-MtTest`, `New-MtTest`, `Convert-MtTest`, `Get-MtSetting` (with the alias
  `Get-MtMaesterConfigGlobalSetting`) and `Get-MtTenantContext`. `Get-MtTestInventory` remains.

## Custom tests

- **Pester-format custom tests keep running**, with Pester 5.7.1 or later installed. Their rows appear in the same
  report. See [Pester-format tests](./writing-tests/pester-format-tests.md).
- **New tests should be native tests**: `Test.<ID>.ps1` with a `[MaesterTest(...)]` attribute plus
  `Test.<ID>.md`, no connection checks, no `try`/`catch`. See [Writing native tests](./writing-tests/index.mdx).
- **`Convert-MtTest -Path ./Custom`** converts Pester-format tests to native tests and reports what needs a
  manual touch.
- **Name your Pester tests `<ID>: <title>`** so that they can be selected with `-TestId` and configured by ID.

## Result changes

The result JSON keeps its 2.x shape; the new fields are additions (`SchemaVersion` is `2.1`). See the
[result schema](./result-schema.md). These rows can come out differently from 2.x:

1. **A built-in test that throws is `Error`, not `Failed`.** In 2.x most exceptions that escaped a check were
   reported as `Failed`. A native test has no assertion, so an exception is never a verdict. `FailedCount` can go
   down and `ErrorCount` up. As in 2.x, such errors do not fail the run or the CI test file unless you set
   `Output.ErrorsAsFailures`.
2. **A test that returns no verdict is `Skipped`** with reason `NoResult`. Tests that decide at run time that they
   do not apply are `Skipped` with reason `NotApplicable` (in 2.x some of these were `Passed`).
3. **A test whose service is not connected is `Skipped`** with reason `ServiceNotConnected`, including the few
   checks that had no connection check in 2.x and reported `Failed` or `Error`.
4. **A family that did not run is one row on the family's ID** (for example `MT.1024`), with `ParentId` set. 2.x
   emitted one `NotRun` row per instance when filtered, and no row when there was nothing to check.
5. **Drift checks are renamed** from `MT1060.<folder>.<n>` to `MT.1060.<folder>.<n>` (the folder name is made
   safe for an ID). The old `MT1060.*` tags are kept, so `-Tag MT1060` still selects them.
6. **`HelpUrl` is filled** for every built-in test; 2.x left it empty for many.
7. **A custom test file that fails to load is reported** as an `Error` row with reason `LoadFailed`; a Pester file
   that failed discovery used to produce no rows.
8. **The top-level `Result` is `Failed`** when any row failed or when Maester itself raised an `Error` row (an
   invalid test or configuration, a file that did not load, a duplicate ID), not when a test merely threw.
9. **Two tests gain tags.** `MT.1022` and `MT.1023` now carry the tags of their whole group, which 2.x dropped.
10. **Maester writes the NUnit/JUnit XML** for native and Pester tests together, with the same test-case names
    (`<Block>.<Name>`) and outcome rules that keep pipelines failing on what they failed on before. See
    [CI test results](./result-schema.md#ci-test-results-nunit-and-junit-xml).

## CI pipelines

- Pipelines that call `New-PesterConfiguration` before `Invoke-Maester` need Pester installed. Either install it
  as a step (`Install-Module Pester -MinimumVersion 5.7.1 -Force -Scope CurrentUser`), or pass a hashtable to
  `-PesterConfiguration`, or move the settings to the run configuration (`Selection`, `Output.TestResult`).
- Pipelines that run `Install-MaesterTests` and then `Invoke-Maester -Path <that folder>` keep working; the folder
  now holds only the README and config template.
- Pipelines that pass `-Path` to a folder of 2.x test copies now run the built-in tests from the module and skip
  the copies. Add `-SkipBuiltIn` only if you want your custom tests alone.
- Use `-Config` or `MAESTER_CONFIG` to give a pipeline its own configuration without touching the repository's
  files.
