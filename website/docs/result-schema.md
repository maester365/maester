---
title: Result schema
sidebar_label: 📄 Result schema
description: Reference for the Maester 3.0 result JSON (schema 2.1), the NUnit and JUnit XML files, and merging the results of a run split across processes.
---

# Result schema

`Invoke-Maester -PassThru` returns the result object, and `-OutputFolder` or `-OutputJsonFile` writes the same
object as JSON. Maester 3.0 keeps the 2.x shape: every 2.x field is still there with the same name, and the new
fields are additions. The result says which shape it has with `SchemaVersion = "2.1"`, meaning "the 2.x shape
plus the additions on this page". A reader written for 2.x keeps working.

Two 2.x fields have other values for the tests that ship with Maester, because those tests are now described by
typed attributes instead of a category and tags: `Block` is the name of the test's product, and `Tag` no longer
lists suite, product or benchmark tags or the test ID. See [Test rows](#test-rows).

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
| `Taxonomy` | object | The display names of the product, feature, area and resource type keys and of the ATT&CK techniques that the rows use (below). |
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

### Taxonomy

A row names its product, feature, area and resource type by key and its ATT&CK techniques by ID. `Taxonomy`
gives the names, so a report can show them without the Maester module:

```json
"Taxonomy": {
  "Products":      [{ "Key": "entra", "Name": "Entra ID" }],
  "Features":      [{ "Product": "entra", "Key": "conditional-access", "Name": "Conditional Access" }],
  "Areas":         [{ "Key": "authentication", "Name": "Authentication" }],
  "ResourceTypes": [{ "Key": "Tenant" }],
  "Attack":        { "Version": "19.2",
                     "Techniques": [{ "Id": "T1110", "Name": "Brute Force", "Tactics": ["TA0006"] }],
                     "Tactics":    [{ "Id": "TA0006", "Name": "Credential Access" }] }
}
```

- It lists only the keys and techniques that the rows of this result use, in the order of the Maester taxonomy:
  `Products` is the order in which reports list products. A feature key is scoped to its product.
- `Attack.Version` is the MITRE ATT&CK Enterprise release the technique IDs were checked against. `Tactics`
  lists the tactics of the listed techniques.
- A custom test may use a product, feature, area or resource type of its own. Such a value has no entry; show it
  as written.
- `Merge-MtMaesterResult -SameRun` rebuilds it for the merged rows.

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

The 2.x fields are all there: `Index`, `Id`, `Title`, `Name`, `HelpUrl`, `Severity`, `Tag`, `Result`,
`ScriptBlock`, `ScriptBlockFile`, `ErrorRecord`, `Block`, `Duration` and `ResultDetail`. `Result` is still exactly
one of `Passed`, `Failed`, `Error`, `Investigate`, `Skipped` and `NotRun`.

For native tests:

- `Name` is `<Id>: <Title>`.
- `Block` is derived from the test's attributes: the display name of its `Product` when the Maester taxonomy
  knows it (`Entra ID`), else `Product` as written, else `Feature`, else the `Name` of its `suite.json`, else
  `Custom`. For a test that ships with Maester it is always the product name. In 2.x it was the `Describe` name,
  such as `Maester/Entra`. A test converted with `Convert-MtTest` keeps its `Describe` name, which is written to
  `Feature`.
- `Tag` lists the tags written in the test's `Tag` attribute and, for a family, the instance's own tags. It does
  not list the tags of the `suite.json`, the test ID, or `Preview` and `LongRunning`. The tests that ship with
  Maester carry no tags for suite, product, benchmark or severity: read `Suite`, `Product`, `Feature`, `Area` and
  `Severity` instead. The Maester 2.x tags still select tests with `-Tag`, but they are not written to the row.
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
| `Source` | string | Where the test comes from: `Maester`, `CISA`, `CIS`, `ASD`, `EIDSCA`, `ORCA` or `Custom` (or the `Source` of a custom `suite.json`). |
| `Suite` | string | The suite ID, for example `Maester`, `CISA`, `AD` or `Custom`. |
| `Product` | string | The key of the product where the fix is made, for example `entra` or `exchange`. `Taxonomy.Products` gives the name. A custom test may use a name of its own. |
| `RelatedProduct` | array of strings | Keys of other products the test also checks or depends on. |
| `Feature` | string | The key of the part of the product the test is about, for example `conditional-access`. `Taxonomy.Features` gives the name. |
| `Area` | string | The key of the security theme, for example `authentication`. `Taxonomy.Areas` gives the name. |
| `ResourceType` | string | What a failing result points at, for example `Tenant` or `User`. |
| `UserImpact` | string | `Low`, `Medium` or `High`: how much the recommended fix disrupts end users. |
| `ImplementationCost` | string | `Low`, `Medium` or `High`: how much administrator work the recommended fix takes. |
| `Mitre` | array of strings | MITRE ATT&CK technique IDs the checked control prevents or detects, or the single value `None`. `Taxonomy.Attack` gives the names and tactics. |
| `Control` | array of strings | Framework requirements the test supports, written `<framework-key>:<requirement-id>`: the values of the test's `Control` attribute, then the controls related to the requirements they name. See [Benchmark](#benchmark). |
| `Lifecycle` | string | `Preview`, `Stable` or `Deprecated`. `Stable` when the test does not say. |
| `ReplacedBy` | string | For a `Deprecated` test, the ID of the test that took its place. |
| `Service` | array of strings | The services the test needs, by their names in the service registry. |
| `License` | array of strings | The service plans the test needs; the tenant needs any one. |
| `Permission` | array of strings | The permissions the test declares, each written `<Service>:<Kind>:<Name>`. The test needs every element; `\|` inside an element joins alternatives, any one of which is enough. Recorded; not enforced. |
| `Benchmark` | object | The requirement of a published benchmark that the test implements: the first value of its `Control` attribute that a framework file knows. `null` when there is none. See [Benchmark](#benchmark). |
| `Format` | string | `Native` or `Pester`. |
| `ReasonCode` | string | Why the test did not run or did not produce a verdict. Empty for `Passed`, `Failed` and `Investigate`. See [Applicability and reason codes](./configuration/applicability.md#reason-codes). |
| `ReasonDetail` | string | The reason in words. For `TestError`, the first line of the error. |
| `ParentId` | string | For a family's rows, the family's ID. Also set on the single row that stands for a whole family that did not run. |
| `InstanceId` | string | For an instance row, its full ID (the same as `Id`). |
| `Parameters` | array | Native tests: the effective parameter values, each `{ Name, Value, Source, Kind }`, where `Source` is `Default`, `Config` or `Parameter`. Empty for Pester rows. |
| `Diagnostics` | array of strings | Warnings (`WARNING: ...`) and non-terminating errors (`ERROR: ...`) the test wrote. |
| `Package` | object | For a test from a [Maester Pack](./packs/index.md): `Id`, `Name`, `Version`, `Commit`, `Publisher`, `BuiltIn` and `Runtime` of the pack. `null` for every other test. A pack's rows always have `Source` `Custom`. |

The fields from `Product` to `Permission` are the test's attributes; see
[the `[MaesterTest]` attribute](./writing-tests/index.mdx#the-maestertest-attribute). A native row always has
all of them: one the test does not declare is `null`, or `[]` for an array. A Pester-format row has them too,
all `null`.

A consumer that tracks results over time should key family rows on `ParentId` when it is present: a family that
did not run is one row on the parent ID, which 2.x never produced.

### Benchmark

A test names the requirements it implements in its `Control` attribute, written
`<framework-key>:<requirement-id>`. A framework file holds the catalogue of a framework: its version and the facts
about each requirement (see
[Benchmarks and framework files](./writing-tests/index.mdx#benchmarks-and-framework-files)). `Benchmark` is the
first `Control` value of the test that names a requirement in a framework file, with what the file says about it:

```json
"Benchmark": { "Framework": "cis-m365", "Version": "7.0.0", "Requirement": "1.1.1",
               "Level": "L1", "Profile": ["E3 Level 1"] }
```

| Field | Content |
| --- | --- |
| `Framework` | The key of the framework. The framework files that ship with Maester are `cis-m365`, `cis-github`, `cisa-scuba`, `essential-eight` and `ism`; a custom suite can declare its own. |
| `Version` | The version of the framework that the framework file describes. |
| `Requirement` | The ID of the requirement, for example `1.1.1` or `MS.AAD.3.5`: the part of the `Control` value after the colon. |
| `Level`, `Profile` | CIS: the level of the recommendation (`L1` or `L2`) and the profiles it belongs to, such as `E3 Level 1`. |
| `Criticality`, `Upstream` | CISA: `SHALL` or `SHOULD`, and where the policy stands in CISA ScubaGear today. `Upstream.Status` is `Current` (`Id` is the policy with its revision, such as `MS.AAD.3.2v2`), `Moved` (`Id` is the policy that took its place and `From` the one it was), `Removed` (with `From` and `Reason`) or `NotFound`. |

The fields after `Requirement` are the facts the framework file gives for that requirement, so a custom framework
may have others. `Benchmark` is `null` on a native row when no `Control` value of the test names a requirement in
a framework file, and on every Pester-format row. In 2.x this was in tags such as `CIS M365 v7.0.0`, `L1` and
`CIS E3 Level 1`.

`Control` lists the values of the test's own `Control` attribute, followed by the references the framework file
gives as `Related` for each requirement they name, each once. The row of `CISA.MS.AAD.3.1` has
`cisa-scuba:MS.AAD.3.1` first, then the NIST SP 800-53 controls that CISA maps the policy to, written
`nist-800-53-r5:<control>`, for example `nist-800-53-r5:IA-2(1)`. A test of another suite that names the same
requirement gets the same `Benchmark` and the same related controls.

`Benchmark` and `Control` say what a test supports. A passed test does not show that the tenant complies with the
benchmark or the control.

`Blocks` has one entry per `Block`, with the same counters as 2.x. For native tests that is one entry per
product.

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

Each test case is named `<Block>.<Name>`, as Pester names it. The names of Pester-format tests, and of tests
converted with `Convert-MtTest`, are what they were in 2.x, so their test history in Azure DevOps and similar
systems continues across the upgrade. The names of the tests that ship with Maester change once, because their
`Block` is now the product name (`Entra ID.MT.1001: ...` instead of `Maester/Entra.MT.1001: ...`). Outcomes:

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
