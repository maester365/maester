---
title: Run configuration reference
sidebar_position: 4
description: Every section and key of maester-config.json in Maester 3.0, how config files are found and layered, and how to pass a configuration with -Config.
---

# Run configuration reference

The run configuration tells Maester which tests to run, with which values, and how to report them. It is the
`maester-config.json` format you know from 2.x, grown with new sections. Every 2.x `maester-config.json`,
`custom/maester-config.json` and `maester-config.<tenantId>.json` loads without changes, and an empty file is an
empty configuration.

Since 3.0 the module no longer ships a row per test: severities come from the tests themselves, so your config
only needs what you want to change. See the [overview](./overview.md) for a short introduction.

## Where the configuration comes from

Maester uses exactly **one** source, in this order:

1. **`-Config`** on `Invoke-Maester` (or `Invoke-MtTest`): a path to a JSON file, a configuration object
   (hashtable or `PSCustomObject`), or an array of paths and objects merged from left to right. The run is
   hermetic: config files next to your tests are not read.

   ```powershell
   Invoke-Maester -Config ./policy.json, @{ Metadata = @{ RunId = 'nightly-42' } }
   ```

2. **The `MAESTER_CONFIG` environment variable**: a path to a config file. Also hermetic.
3. **The files Maester finds**, starting from `-Path` (or the current folder when `-Path` is not given). Each is
   an optional layer, and each merges over the one before:

   | Layer | Found at |
   | --- | --- |
   | `maester-config.json` | `-Path`, then `-Path/tests`, then up to five parent folders. The first match wins. |
   | `custom/maester-config.json` | The `custom` folder next to that root file, or under `-Path` or `-Path/tests` when there is no root file. |
   | `maester-config.<tenantId>.json` | Searched like the root file, once Maester knows the tenant ID from the Graph connection. |

Under every source sits a small defaults layer (the default values of the global settings). Command-line
parameters sit on top of every source.

Two changes from 2.x:

- **The tenant file is merged, not substituted.** In 2.x `maester-config.<tenantId>.json` was loaded instead of
  `maester-config.json`. In 3.0 it is merged over `maester-config.json` and `custom/maester-config.json`, and wins
  over both. A tenant now inherits base settings it does not set itself; Maester warns once and names the global
  settings it inherited. Set them in the tenant file to override them.
- **`Custom/maester-config.json` works on its own.** In 2.x it was ignored without a root file beside it.

If a `maester-config.json` looks like a copy of the file Maester 2.x shipped (300 or more `TestSettings` rows that
all have a `Title`), Maester warns: its rows override the severities the tests now carry. Keep only the rows you
changed.

A config file found in a parent folder applies to every run below it. When such a file (outside `-Path`) sets
`Selection`, `Environment` or `Output`, Maester warns, so that a stray file cannot quietly change what runs. Pass
the config with `-Config` if that is what you want. `-Verbose` logs the full path of every config file used.

`ConfigSource` in the result's `MaesterConfig` names the sources that were used.

### Merge rules

- `TestSettings` rows merge per `Id` (case-insensitive) and per property: a higher layer can change one property
  of a row without repeating the others.
- Every other object merges per key, recursively.
- Arrays and plain values replace. An empty array in a higher layer clears the lower one.
- On the command line, `-Tag` and `-TestId` replace the config's `Selection.Tag` and `Selection.TestId`;
  `-ExcludeTag` and `-ExcludeTestId` add to the config's lists; `-IncludePreview` and `-IncludeLongRunning` turn
  the setting on when either source does.

Keys Maester does not know are kept and passed through, so they do no harm. The 2.x keys `ModuleVersion` and
`ConfigVersion` are ignored.

## A complete example

```json
{
  "Metadata": { "RunId": "2026-10-06-nightly", "RequestedBy": "security-pipeline" },
  "GlobalSettings": {
    "EmergencyAccessAccounts": [
      { "Type": "User", "UserPrincipalName": "BreakGlass1@contoso.com" },
      { "Type": "Group", "Id": "00000000-0000-0000-0000-000000000000" }
    ]
  },
  "Selection": {
    "BuiltIn": "All",
    "DefaultAction": "Run",
    "Tag": [],
    "ExcludeTag": [],
    "TestId": [],
    "ExcludeTestId": ["MT.1024.*"],
    "IncludePreview": false,
    "IncludeLongRunning": false,
    "OnUnknownId": "Warn"
  },
  "TestSettings": [
    { "Id": "MT.1005", "Severity": "Critical" },
    { "Id": "MT.1089", "Enabled": false, "Reason": "Not relevant for this tenant" },
    { "Id": "MT.1198", "Parameters": { "MaximumValidityDays": 180 }, "TimeoutSeconds": 600 }
  ],
  "Environment": {
    "TenantType": "Auto",
    "Cloud": "GCC",
    "Licenses": "Auto",
    "Services": "Auto",
    "Enforce": { "Service": true, "License": true, "TenantType": false, "Cloud": false }
  },
  "Execution": { "TestTimeoutSeconds": 0, "LongRunningTimeoutSeconds": 0 },
  "Output": {
    "ErrorsAsFailures": false,
    "TestResult": { "Format": "NUnitXml", "Path": "./test-results/maester.xml" }
  }
}
```

Every section is optional.

## Metadata

Free-form values about the run, echoed in the result as `RunMetadata`. Use it to tag a run, for example with a
`RunId` shared by the parts of a [split run](../result-schema.md#splitting-a-run-across-processes).

## GlobalSettings

Tenant-wide settings that tests read with `Get-MtSetting`. Maester knows these:

| Setting | Type | Default | Used by |
| --- | --- | --- | --- |
| `EmergencyAccessAccounts` | array | none | Conditional Access checks. See [Emergency access accounts](./emergency-access-accounts.md). |
| `DataverseEnvironmentUrl` | string | | Copilot Studio checks. |
| `GitHubOrganization` | string | | GitHub checks. |
| `GitHubApiBaseUri` | string | `https://api.github.com` | GitHub checks. |
| `GitHubApiVersion` | string | `2022-11-28` | GitHub checks. |
| `XspmExternalDataUris` | object | built-in sources | XSPM checks. See the [overview](./overview.md#xspm-external-data-sources). |

Any other key is passed through. Custom tests and test packs should use a `Namespace.Key` name, for example
`Contoso.SiteUrl`.

## Selection

Which tests run. Every key has a command-line equivalent.

| Key | Values | Default | Effect |
| --- | --- | --- | --- |
| `BuiltIn` | `All`, `None` | `All` | `None` runs only your custom tests, like `-SkipBuiltIn`. |
| `DefaultAction` | `Run`, `Skip` | `Run` | `Skip` is allow-list mode: a test runs only if a `TestSettings` row for its ID sets `"Enabled": true`. Others are `NotRun` with reason `NotListed`. |
| `Tag` | array | `[]` | Run only tests with any of these tags (like `-Tag`). |
| `ExcludeTag` | array | `[]` | Do not run tests with any of these tags (like `-ExcludeTag`). |
| `TestId` | array | `[]` | Run only these IDs (like `-TestId`). |
| `ExcludeTestId` | array | `[]` | Do not run these IDs (like `-ExcludeTestId`). Wins over `TestId`. |
| `IncludePreview` | bool | `false` | Run preview tests (like `-IncludePreview`). |
| `IncludeLongRunning` | bool | `false` | Run long-running tests (like `-IncludeLongRunning`). |
| `OnUnknownId` | `Warn`, `Ignore`, `Error` | `Warn` | What to do when an ID you named matches no test. `Error` stops the run before any test runs. |

Rules:

- Tags and IDs are compared case-insensitively. Tag lists match any tag; `*` wildcards are allowed.
- Test IDs are exact or use `*` wildcards (`CISA.MS.AAD.3.*`). An ID named exactly runs even if the test is
  preview or long-running; a wildcard match does not lift those exclusions.
- Every test's ID is also one of its tags, so `-Tag MT.1068` keeps working.
- Preview tests are left out unless `IncludePreview` is set or any `Tag` is given. Long-running tests are left out
  unless `IncludeLongRunning` is set or `Tag` contains `LongRunning` or `CAWhatIf`.
- The tags `All` and `Full` were removed in 3.0 (in 2.x they were deprecated and selected nothing). Using
  them stops the run; use `IncludePreview` and `IncludeLongRunning` instead.
- Active Directory tests run only after `Connect-Maester -Service ActiveDirectory`, whatever the selection says.
- In `DefaultAction: Skip` mode, a row with only `Severity` or `Parameters` does not admit a test, and admission
  is only the first gate: tag, preview and long-running rules still apply. A row on a family's parent ID or on
  any of its instance IDs admits the family. With no `"Enabled": true` rows at all, nothing runs.
- Unknown IDs are listed in the result under `Selection.UnknownIds`. An ID under a declared family's parent ID is
  never unknown, so you can keep a row for an instance that does not exist in this run.

Deselected and disabled tests still appear in the result as `NotRun` rows with a reason code. See
[Applicability and reason codes](./applicability.md).

## TestSettings

One row per test you want to change, built-in or custom, native or Pester-format.

| Key | Type | Effect |
| --- | --- | --- |
| `Id` | string | The test ID, or a family instance ID (`MT.1024.<suffix>`). Required. |
| `Severity` | string | `Critical`, `High`, `Medium`, `Low` or `Info`. Overrides the test's own severity. |
| `Enabled` | bool | `false` turns the test off: it is not run and appears as `NotRun` with reason `DisabledByConfig`. `true` admits it in `DefaultAction: Skip` mode. |
| `Reason` | string | Shown as the reason of a disabled test. |
| `Parameters` | object | Values for the test's parameters, by name. Native tests only. |
| `TimeoutSeconds` | int | A timeout for this test, overriding `Execution`. Native tests only. |

For a family, a row on an instance ID wins over a row on the parent ID. `"Enabled": false` on the parent ID turns off the whole family; on an instance ID it
turns off only that instance, and the others still run.

Parameter values are checked against the test's `param()` block before it runs. Use `Get-MtTest <ID>` to see a
test's parameters, their types, defaults, allowed values and descriptions.

| Parameter type | Accepted JSON value |
| --- | --- |
| `int` | A whole number in the 32-bit range |
| `bool`, `switch` | `true` or `false` |
| `string` | A string, or `{ "Id": "...", "DisplayName": "..." }` (the test receives the `Id`) |
| `string[]` | A string or an array of strings (or of `{ "Id": ... }` objects) |

A name the test does not have, a fraction, a value of the wrong type, a value outside the parameter's
`ValidateRange` or `ValidateSet`, a value that does not match its [kind](../writing-tests/index.mdx#parameter-kinds),
a common parameter name, or an engine-owned name (`Instance`, `Mt*`) gives that test an `Error` row with reason
`InvalidConfiguration`. The rest of the run carries on.

## Environment

The facts Maester uses to decide whether a test applies, and which of those checks are enforced. Each fact is
`Auto` (detect it, the default) or a forced value.

| Key | Values | Effect |
| --- | --- | --- |
| `TenantType` | `Auto`, `Workforce`, `External` | Forces the tenant type. |
| `Cloud` | `Auto`, `Commercial`, `GCC`, `GCCHigh`, `DoD`, `China`, `Bleu`, `Delos`, `GovSG` | Forces the cloud. Set `GCC` for a GCC tenant: Graph cannot tell GCC from Commercial. |
| `Licenses` | `Auto`, or an array of service plan names | Forces the tenant's licences. |
| `Services` | `Auto`, or an object such as `{ "Teams": false, "Graph": true }` | Forces the connection state of the services named. Others are still detected. |
| `Enforce` | object | Which checks skip tests: `Service` (default `true`), `License` (default `true`), `TenantType` (default `false`), `Cloud` (default `false`). |

Forcing a service to `true` does not connect it: tests that need it run and fail if it is not really connected.
Forcing is meant for runs split across processes, where every part should reach the same decisions. The detected
and forced values are recorded in the result's `TenantContext`. See [Applicability](./applicability.md).

## Execution

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `TestTimeoutSeconds` | int | `0` (none) | Stops a native test that runs longer and reports it as `Error` with reason `Timeout`. |
| `LongRunningTimeoutSeconds` | int | `0` (use `TestTimeoutSeconds`) | The timeout for tests marked `LongRunning`. |
| `MaxParallel` | int | `1` | Reserved for parallel execution. Maester 3.0 runs tests one at a time and ignores it. |

A test's own `TestSettings[].TimeoutSeconds` wins over `LongRunningTimeoutSeconds`, which wins over
`TestTimeoutSeconds`; a more specific value of `0` turns the broader timeout off for those tests. Timeouts are off
by default. On a host that stops a run after a period without console
output, keep every timeout below that period: a test writes nothing while it runs.

## Output

| Key | Type | Default | Effect |
| --- | --- | --- | --- |
| `ErrorsAsFailures` | bool | `false` | When `true`, a test that threw (`TestError`, `Timeout`, `InvalidReturn`) fails the run's `Result` and is a failure in the XML file. |
| `TestResult.Path` | string | none | Writes NUnit or JUnit XML for native and Pester-format tests to this path. From a config file found by folder discovery, only a relative path inside the current folder is accepted; `-Config` and `MAESTER_CONFIG` may name any path. |
| `TestResult.Format` | string | `NUnitXml` | `NUnitXml` or `JUnitXml`. |
| `ConsoleMode` | string | `Auto` | How the console output is written: `Interactive` (a live status line with the result counts and the running test), `Stream` (lines only, for CI and redirected output), `Plain` (lines without colour or symbols) or `Auto` (Interactive on a terminal, Stream otherwise). `-OutputMode` and the `MAESTER_OUTPUT_MODE` environment variable win over it. |
| `DashboardPanels` | string[] | all of them | The panels of the full-screen dashboard of an interactive run, in order: `Tenant` (tenant name, primary domain and account), `Totals` (the results so far as a bar split by result, with the counts), `Connections` (the services of the run and which of them are connected), `Failed` (failed tests by severity), `Drift` (changes against the newest earlier results file in the output folder), `Slowest` (the tests that took the longest), `Blog` (the newest post on maester.dev), `Version` (not a panel: a newer Maester on the PowerShell Gallery is mentioned under the logo, as a link), `Tips`, `Contributor` (one of the people who built Maester, with a link to their page), `Pace` (a graph of how long each test took) and `Results` (one block per test). `Pace` and `Results` are in the main column (the graph at the top, next to the logo; the blocks under the product lanes); the others show in a column on the right when the console is about 140 columns or wider. `Blog` and `Version` each make one web request in the background, and are left out with `-SkipVersionCheck`. An empty list turns the panels off. |
| `CIAnnotations` | bool | `true` | On GitHub Actions and Azure Pipelines, writes the first 20 Failed (as warnings) and Error (as errors) rows as annotations. |

See [CI test results](../result-schema.md#ci-test-results-nunit-and-junit-xml) for how each result maps to an XML
outcome.

## Checking what a configuration does

```powershell
# Which tests would run, and why the others would not
$r = Invoke-Maester -DryRun -PassThru
$r.MaesterConfig.ConfigSource
$r.Tests | Where-Object Result -EQ 'NotRun' | Group-Object ReasonCode
```

A `-DryRun` runs no native test and sends no mail or Teams message, but still writes the report files, so you can
open the report and look at the plan. Pester-format custom tests still go through Pester discovery, which runs
their `BeforeDiscovery` and `Describe`-level code.
