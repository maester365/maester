---
title: Applicability and reason codes
sidebar_position: 5
description: How Maester decides whether each test runs, and what every reason code on a result row means.
---

# Applicability and reason codes

Every test Maester knows about appears in the result, whether it ran or not. A test that did not run, or did not
produce a verdict, has a `ReasonCode` and a human-readable `ReasonDetail` on its row. This page explains how
Maester reaches that decision and what you can do about each reason.

Use `Invoke-Maester -DryRun -PassThru` to see the decision for every test without running any test. Each test that
would have run is reported as `NotRun` with reason `DryRun`; every other row is the row a real run would give.
(Pester-format custom tests still go through Pester discovery, which runs their `BeforeDiscovery` code.)

```powershell
$plan = Invoke-Maester -DryRun -PassThru
$plan.Tests | Group-Object Result, ReasonCode | Sort-Object Count -Descending | Format-Table Count, Name
```

## The order of the checks

For each native test, Maester applies these checks in order. The first one that fails decides the row, so a
row has exactly one reason.

| # | Check | Fails as |
| --- | --- | --- |
| 1 | The test file is valid, loads, has a unique ID and does not need a newer Maester | `Error` |
| 2 | The test is not disabled in `TestSettings` | `NotRun` |
| 3 | `Selection.DefaultAction = Skip` and no `TestSettings` row enables it | `NotRun` |
| 4 | Selection by ID: `-ExcludeTestId`, then `-TestId` | `NotRun` |
| 5 | Selection by tag: `-Tag`, then the Active Directory opt-in, then `-ExcludeTag`, Preview and long-running | `NotRun` |
| 6 | Platform: the operating system Maester runs on | `Skipped` |
| 7 | Tenant type (only when enforced) | `Skipped` |
| 8 | Cloud (only when enforced) | `Skipped` |
| 9 | Service: every service in `Service` is known and connected | `Skipped` |
| 10 | Licence: the tenant has a compatible licence (only when licences could be read) | `Skipped` |
| 11 | Parameter values from the config are valid | `Error` |
| 12 | `-DryRun` stops here | `NotRun` |

Then the test runs. A family first calls its instance source; then each instance runs. The test's own outcome
decides the rest (see [What the function returns](../writing-tests/index.mdx#what-the-function-returns)).

Rows that come from a check the engine made without running the test (`NotRun`, and the `Skipped` rows from
checks 6 to 10) still carry the test's description from its `.md` file. For service and licence skips the row
also carries the 2.x skip code in `ResultDetail.TestSkipped` (for example `NotConnectedExchange`), so reports
read as they did in 2.x.

### The facts the checks use

Maester builds a tenant context once per run and records it in the result as `TenantContext`. You can see it
any time with `Get-MtTenantContext`.

| Fact | Detected from | When it cannot be detected |
| --- | --- | --- |
| Platform | The operating system running PowerShell | |
| Services | `Test-MtConnection` for each service the tests need | Not connected |
| Licences | The tenant's enabled `subscribedSkus` | `Unknown`: the licence check is skipped and the test runs |
| Tenant type | `organization.tenantType`: `AAD` is `Workforce`, `CIAM` is `External` | `Unknown`: never skips a test |
| Cloud | The Microsoft Graph environment: `Global` is `Commercial` (assumed), `USGov` is `GCCHigh`, `USGovDoD` is `DoD`, `China` is `China` | `Unknown`: never skips a test |

GCC tenants use the worldwide Graph endpoint, so they cannot be told apart from Commercial. A GCC tenant states
`"Cloud": "GCC"` under `Environment` in its config.

Any fact can be forced in the [run configuration](./run-configuration.md#environment), and the enforcement of
each check can be switched:

```json
{
  "Environment": {
    "Cloud": "GCC",
    "Services": { "Teams": false },
    "Enforce": { "Service": true, "License": true, "TenantType": false, "Cloud": false }
  }
}
```

The defaults are shown above: service and licence checks are on; tenant type and cloud are detected and recorded
but do not skip tests until you turn them on. The platform check is always on.

## Reason codes

`Result` is always one of `Passed`, `Failed`, `Error`, `Investigate`, `Skipped` and `NotRun`. `Passed`, `Failed`
and `Investigate` rows have no reason code. The reason codes below are a closed list.

### NotRun

The test was not run because of what you asked for.

| Reason code | Meaning | What you can do |
| --- | --- | --- |
| `DisabledByConfig` | A `TestSettings` row sets `"Enabled": false`. `ReasonDetail` is the row's `Reason`, if any. | Remove the row or set `Enabled` to `true`. |
| `NotListed` | `Selection.DefaultAction` is `Skip` and no `TestSettings` row sets `"Enabled": true` for this test (or, for a family, for its parent or any instance). | Add `{ "Id": "<ID>", "Enabled": true }`, or use `DefaultAction: Run`. |
| `ExcludedById` | The ID matches `-ExcludeTestId` or `Selection.ExcludeTestId`. | Remove the pattern. |
| `NotSelected` | `-TestId` (or `Selection.TestId`) was given and does not match this test, or `-Tag` was given and the test has none of the tags. For a family, an instance that a `-TestId` naming other instances did not cover. | Add the ID or tag, or drop the filter. |
| `ExcludedByTag` | The test has a tag in `-ExcludeTag`, `Selection.ExcludeTag` or `PesterConfiguration.Filter.ExcludeTag`. | Remove the tag from the exclusions. |
| `Preview` | A preview test, excluded by default. | `-IncludePreview`, any `-Tag`, `Selection.IncludePreview`, or name its exact ID in `-TestId`. |
| `LongRunning` | A long-running test, excluded by default. | `-IncludeLongRunning`, `-Tag LongRunning` or `-Tag CAWhatIf`, `Selection.IncludeLongRunning`, or name its exact ID in `-TestId`. |
| `OptInServiceNotConnected` | An Active Directory test, and Active Directory is not connected. These tests are opt-in. | `Connect-Maester -Service ActiveDirectory`. |
| `DryRun` | `-DryRun`: the test would have run. | Run without `-DryRun`. |
| `DeselectedAtRuntime` | Pester-format tests only: an instance of a test whose name is built at run time ran although the run selected other instances or excluded this one. Its result is not reported. | Nothing; select the instances you want by ID. |

A wildcard in `-TestId` does not lift the Preview and long-running exclusions; an exact ID does.

### Skipped

The test applies to some tenants but not, or not now, to this one.

| Reason code | Meaning | What you can do |
| --- | --- | --- |
| `ServiceNotConnected` | A service in the test's `Service` list is not connected. `ReasonDetail` names it. | Connect it, for example `Connect-Maester -Service ExchangeOnline`. |
| `ServiceNotRegistered` | A custom test names a service this Maester version does not know. | Fix the name (see the [service list](../writing-tests/index.mdx#service)) or update Maester. |
| `LicenseNotFound` | The tenant has none of the licences in `License`. | Nothing, if the licence is not in use. To force the decision, set `Environment.Licenses`, or turn the check off with `Environment.Enforce.License = false`. |
| `TenantTypeMismatch` | Tenant type is enforced and the test does not apply to this type of tenant. | Turn off `Environment.Enforce.TenantType`, or correct `Environment.TenantType`. |
| `CloudMismatch` | Cloud is enforced and the test does not apply to this cloud. | Turn off `Environment.Enforce.Cloud`, or correct `Environment.Cloud`. |
| `PlatformMismatch` | The test runs only on another operating system (for example Windows). | Run it on that operating system. |
| `NotApplicable` | The test called `Add-MtTestResultDetail -SkippedBecause NotApplicable`: it decided at run time that it does not apply. | Nothing. |
| `TestSkipped` | The test skipped itself with `-SkippedBecause` for another reason. The 2.x code (for example `NotSupportedAppPermission`) is in `ResultDetail.TestSkipped`. | Read `ReasonDetail`. |
| `NoInstances` | A family's instance source returned nothing: there is nothing in this tenant to check. | Nothing. |
| `NoResult` | The test returned `$null` without skipping. | For a custom test: return `$true` or `$false`, or skip explicitly. |

### Error

The test, its configuration or its file has a problem. Errors that Maester raises without running the test fail
the run and the CI test results; errors raised by the test itself do not, unless you set
`Output.ErrorsAsFailures` (see [Result schema](../result-schema.md#top-level-result)).

| Reason code | Raised by | Meaning | What you can do |
| --- | --- | --- | --- |
| `TestError` | The test | The test threw an error or called `-SkippedBecause Error`. `ReasonDetail` is the first line of the message; `ErrorRecord` holds the full record. | Read the message. Often a missing permission or an API failure. |
| `Timeout` | The test | The test ran longer than its timeout. | Raise `Execution.TestTimeoutSeconds` or the test's `TimeoutSeconds`. |
| `InvalidReturn` | The test | The test returned something that is not `$true` or `$false`, or several values. | For a custom test: return one boolean, and send stray output to `$null`. |
| `InvalidMetadata` | Maester | The `[MaesterTest]` attribute, the parameters, or the file layout break a rule, or a custom test has no `.md` file. `ReasonDetail` names the file and line. | Run `Get-MtTest -Path <file>` and fix what it lists. |
| `InvalidConfiguration` | Maester | A parameter value from the config (or `Invoke-MtTest -Parameter`) is not valid for the test. | Fix the value in `TestSettings[].Parameters`. `Get-MtTest <ID>` lists the parameters. |
| `LoadFailed` | Maester | A custom test file does not parse or could not be loaded. | Fix the syntax error named in `ReasonDetail`. |
| `DuplicateId` | Maester | Two native tests have the same ID or function name. Neither runs. (A Pester-format test with the ID of a native test is superseded instead.) | Rename one, or delete the copy. |
| `RequiresNewerMaester` | Maester | The test or its `suite.json` needs a newer Maester. | Update Maester. |
| `InstanceSourceFailed` | Maester | A family's instance source threw. One row on the parent ID. | Read the message; often a permission or connection problem. |
| `InvalidInstanceId` | Maester | A family's instance source returned an instance whose `Id` is missing, invalid or repeated. One row on the parent ID. | For a custom test: return unique IDs that match `^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`. |
| `ForeignModuleLoaded` | Maester | Another Maester version was loaded into the session while the test ran (usually because something called a 2.x function), so the result cannot be trusted. Maester removes it and carries on. | Uninstall Maester 2.x: `Uninstall-Module Maester -MaximumVersion 2.99.99 -AllVersions`. |
| `PesterNotAvailable` | Maester | The run has Pester-format tests and Pester 5.7.1 or later is not installed. | `Install-Module Pester -MinimumVersion 5.7.1 -Scope CurrentUser`. |

## Not in the result at all

Two kinds of test produce no row:

- A Pester-format test that is a stale copy of a built-in test. It is listed under `Selection.Superseded` in the
  result instead. See [Pester-format tests](../writing-tests/pester-format-tests.md#copies-of-built-in-tests-are-not-run).
- A custom native test that uses the ID of a built-in test. It is not loaded, Maester warns, and the built-in
  runs.

IDs you name in the selection or the config that match no test are listed under `Selection.UnknownIds`. By
default that is a warning; see `Selection.OnUnknownId` in the [run configuration](./run-configuration.md#selection).
