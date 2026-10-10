---
title: Result schema
sidebar_label: 📄 Result schema
description: Reference for the Maester 3.0 result JSON (schema 2.1), the NUnit and JUnit XML files, and merging the results of a run split across processes.
---

# Result schema

`Invoke-Maester -PassThru` returns the result object, and `-OutputFolder` or `-OutputJsonFile` writes the same
object as JSON. Maester 3.0 keeps the 2.x shape: every 2.x field is still there with the same name and meaning,
and the new fields are additions. The result says which shape it has with `SchemaVersion = "2.1"`, meaning "the
2.x shape plus the additions on this page". A reader written for 2.x keeps working.

## Top level

The 2.x fields are unchanged: `Result`, `FailedCount`, `PassedCount`, `ErrorCount`, `InvestigateCount`,
`SkippedCount`, `NotRunCount`, `TotalCount`, `ExecutedAt`, `TotalDuration`, `UserDuration`,
`DiscoveryDuration`, `FrameworkDuration`, `TenantId`, `TenantName`, `TenantLogos`, `Account`,
`CurrentVersion`, `LatestVersion`, `SystemInfo`, `PowerShellInfo`, `LoadedModules`, `InvokeCommand`,
`MgContext`, `PesterConfig`, `MaesterConfig`, `Tests`, `Blocks` and `EndOfJson` (always last). `OutputFiles` and
`AffectedObjects` appear when requested, as before.

Added in 2.1:

| Field | Type | Content |
| --- | --- | --- |
| `SchemaVersion` | string | `"2.1"`. |
| `CatalogVersion` | string | The version of the built-in test catalog, equal to the module version. Results are comparable when this matches. |
| `TenantContext` | object | The facts the run used to decide which tests apply (below). |
| `RunMetadata` | object | The `Metadata` section of the run configuration, echoed as given (for example a run ID). An empty object when not set. |
| `Selection` | object | How the run selected tests (below). |
| `Partitions` | array | Only in a result merged with `Merge-MtMaesterResult -SameRun` (see [Splitting a run](#splitting-a-run-across-processes)). |

### TenantContext

| Field | Content |
| --- | --- |
| `TenantId`, `TenantName` | From the Graph connection. |
| `TenantType`, `TenantTypeSource` | `Workforce`, `External` or `Unknown`; source `Detected`, `Config` or `Unknown`. |
| `Cloud`, `CloudSource` | `Commercial`, `GCC`, `GCCHigh`, `DoD`, `China`, ... or `Unknown`; source `Detected`, `Assumed` (Commercial, which cannot be told apart from GCC), `Config` or `Unknown`. |
| `Platform` | `Windows`, `Linux` or `MacOS`. |
| `Services` | One property per service the run's tests need, `true` when connected. |
| `Licenses` | `State` (`Known` or `Unknown`), `ServicePlanNames`, `ServicePlanIds`, `SkuIds`, `Source` (`Detected`, `Config` or `Unknown`). |
| `AuthType`, `Account`, `Scopes` | From the Graph connection. |

### Selection

| Field | Content |
| --- | --- |
| `BuiltIn` | `All`, or `None` when the run used `-SkipBuiltIn` or `Selection.BuiltIn = None`. |
| `UnknownIds` | IDs named in `-TestId`, `-ExcludeTestId`, `Selection.TestId`, `Selection.ExcludeTestId` or a `TestSettings` row with `Enabled`, that match no test. Wildcards and IDs under a family's parent ID are never listed. |
| `Superseded` | Pester-format tests that were not run because they are stale copies of built-in tests, or share an ID with a native test: `Id`, `File`, `MatchedBy` (`BuiltInId`, `PreviousId`, `FamilyPrefix` or `NativeTest`). |
| `IncludeTag` | The effective include tags. |
| `ExcludeTag` | The effective exclude tags, including the ones Maester adds by default (`Preview`, `LongRunning`, `AD`). |
| `DryRun` | `true` for a `-DryRun` result. |

### MaesterConfig

`MaesterConfig` is the effective run configuration after every layer was merged (see
[Run configuration](./configuration/run-configuration.md)), with the 3.0 sections (`Selection`, `Metadata`, and
any `Environment`, `Execution` and `Output` you set). `ConfigSource` names the sources that contributed, lowest
first, for example `maester-config.json, custom/maester-config.json`, `-Config`, or `defaults` when no file was
found.

When the run has native tests, `MaesterConfig.TestSettings` lists one row per test in the run: `Id`, `Title`, the
effective `Severity`, `DefaultSeverity` (the attribute's, for built-in tests), and any other keys you set for that
test. This keeps the report's configuration page complete now that the module no longer ships a row per test.

### Top-level Result

`Result` is `Failed` when any row is `Failed`, when the Pester run reported `Failed`, or when Maester itself raised
an `Error` row without running the test (reason `InvalidMetadata`, `InvalidConfiguration`, `InvalidInstanceId`,
`DuplicateId`, `LoadFailed`, `InstanceSourceFailed`, `RequiresNewerMaester`, `ForeignModuleLoaded` or
`PesterNotAvailable`). A test that threw (`TestError`, `Timeout`, `InvalidReturn`) does not fail the run, as in
2.x, unless the run configuration sets `"Output": { "ErrorsAsFailures": true }`. Otherwise `Result` is `Passed`.

## Test rows

`Tests` has one row per test, or per instance of a family. Rows are sorted as in 2.x: `Passed` and `Failed` rows
first, then the rest, each group by `Name`; `Index` numbers them in that order.

The 2.x fields are unchanged: `Index`, `Id`, `Title`, `Name`, `HelpUrl`, `Severity`, `Tag`, `Result`,
`ScriptBlock`, `ScriptBlockFile`, `ErrorRecord`, `Block`, `Duration` and `ResultDetail`. `Result` is still exactly
one of `Passed`, `Failed`, `Error`, `Investigate`, `Skipped` and `NotRun`.

For native tests:

- `Name` is `<Id>: <Title>`, and `Block` is the attribute's `Category`.
- `ScriptBlock` is empty. `ScriptBlockFile` is the path relative to the repository (`tests/...`) for a built-in
  test, and the full path for a custom test.
- `Duration` has millisecond precision (`hh:mm:ss.fff`).
- `HelpUrl` is filled from the suite's template when the test does not set one.
- `ResultDetail` has the 2.x fields (`TestTitle`, `TestDescription`, `TestResult`, `TestSkipped`,
  `SkippedReason`, `TestInvestigate`, `Severity`, `Service`) even for rows the engine produced without running the
  test, so older readers can show the description and the reason.

Added in 2.1:

| Field | Type | Content |
| --- | --- | --- |
| `Source` | string | Where the test comes from: `Maester`, `CISA`, `CIS`, `EIDSCA`, `ORCA` or `Custom` (or the `Source` of a custom `suite.json`). |
| `Suite` | string | The suite ID, for example `Maester`, `CISA`, `AD` or `Custom`. |
| `Product` | string | Native tests: the attribute's `Product`, for example `Entra ID` or `Exchange Online`; null when the test does not set one. Not present on Pester rows. |
| `Format` | string | `Native` or `Pester`. |
| `ReasonCode` | string | Why the test did not run or did not produce a verdict. Empty for `Passed`, `Failed` and `Investigate`. See [Applicability and reason codes](./configuration/applicability.md#reason-codes). |
| `ReasonDetail` | string | The reason in words. For `TestError`, the first line of the error. |
| `ParentId` | string | For a family's rows, the family's ID. Also set on the single row that stands for a whole family that did not run. |
| `InstanceId` | string | For an instance row, its full ID (the same as `Id`). |
| `Parameters` | array | Native tests: the effective parameter values, each `{ Name, Value, Source, Kind }`, where `Source` is `Default`, `Config` or `Parameter`. Empty for Pester rows. |
| `Diagnostics` | array of strings | Warnings (`WARNING: ...`) and non-terminating errors (`ERROR: ...`) the test wrote. |

A consumer that tracks results over time should key family rows on `ParentId` when it is present: a family that
did not run is one row on the parent ID, which 2.x never produced.

`Blocks` has one entry per `Block` (category), with the same counters as 2.x.

## CI test results (NUnit and JUnit XML)

Maester writes one XML file that covers native and Pester-format tests. Ask for it in the run configuration:

```json
{ "Output": { "TestResult": { "Format": "NUnitXml", "Path": "./test-results/maester.xml" } } }
```

or, as in 2.x, through `-PesterConfiguration` with `TestResult.Enabled = $true` (plus `OutputPath` and
`OutputFormat`; the default path is `testResults.xml`). The config wins when both are set. `Format` is `NUnitXml`
(NUnit 2.5, the default) or `JUnitXml`. Other formats, such as NUnit 3, are left to Pester and hold only the
Pester-format tests, with a warning. No XML is written for a `-DryRun`.

- A relative `Path` is resolved against the current PowerShell location.
- A config file that Maester found by folder discovery may only set a relative path inside the current folder;
  any other path is ignored with a warning and no XML is written. A configuration passed with `-Config` or
  `MAESTER_CONFIG`, or a `-PesterConfiguration`, may name any path.
- With `-RedactUserIdentity AllOutputs` the XML file is redacted like the other exports.
- If the file cannot be written, Maester warns and still writes the other reports.

Each test case is named `<Block>.<Name>`, as Pester names it, so test history in Azure DevOps and similar
systems continues across the upgrade. Outcomes:

| Row | XML outcome |
| --- | --- |
| `Passed` | Success |
| `Failed` | Failure |
| `Error` raised by Maester without running the test (`InvalidMetadata`, `InvalidConfiguration`, `InvalidInstanceId`, `DuplicateId`, `LoadFailed`, `InstanceSourceFailed`, `RequiresNewerMaester`, `ForeignModuleLoaded`, `PesterNotAvailable`) | Failure, with the message |
| `Error` from the test (`TestError`, `InvalidReturn`, `Timeout`) | Ignored (skipped), with the message; Failure when `Output.ErrorsAsFailures` is `true` |
| `Skipped` | Ignored (skipped), with `ReasonDetail` |
| `Investigate` | Success if a native test returned `$true`, Failure if it returned `$false`, otherwise Ignored |
| `NotRun` | Left out, as Pester does |

This keeps pipelines that fail on failed tests failing on the same things as in 2.x, where nearly every error was
reported as skipped.

## Splitting a run across processes

A run can be split into parts that run separately, for example Graph tests in one container and Exchange tests
in another, or Windows-only tests on a Windows agent, and then merged into one result.

1. Run `Invoke-Maester -DryRun -PassThru` once to get the plan, and group the tests by whatever key you need
   (`Source`, `Suite`, the services the tests need, platform).
2. Run each part as an ordinary run with `-TestId <the part's IDs>`. Give every part the same Maester version,
   the same `Metadata.RunId`, and the same `Environment` values, so each part reaches the same decisions. Each
   process connects on its own; sessions are never shared across processes.
3. Merge the JSON files:

```powershell
# In each process
Invoke-Maester -TestId $ids -Config @{ Metadata = @{ RunId = '2026-10-06-nightly' } } -OutputJsonFile "./parts/$name.json"

# Afterwards
Merge-MtMaesterResult -Path ./parts/*.json -SameRun | Get-MtHtmlReport | Out-File ./report.html
```

[`Merge-MtMaesterResult`](./commands/Merge-MtMaesterResult.mdx) `-SameRun`:

- Unites the rows by `Id`. A row that ran (any result other than `NotRun`) replaces a `NotRun` row for the same ID,
  so each part's `NotRun`/`NotSelected` rows for tests another part ran are dropped. A family's single `NotRun` row
  on its parent ID is dropped when another part ran the family's instances. If two parts both ran a test, the
  first result is kept with a warning.
- Recomputes the counters, `Blocks` and the top-level `Result`.
- Keeps each part's `TenantId`, `TenantContext`, `ExecutedAt`, `TotalDuration`, `Result`, `TotalCount` and
  `InvokeCommand` under `Partitions`.
- Refuses to merge results with different `CatalogVersion` values, or different `RunMetadata.RunId` values when
  they have one.

Because every part reports every test it did not run as `NotRun`, the merged result covers the whole catalog.
Without `-SameRun`, `Merge-MtMaesterResult` builds a multi-tenant report from runs against different tenants, as
in 2.x.
