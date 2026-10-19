# Design: the Zero Trust Assessment pack

> **Status: DRAFT.** Drafted 2026-10-19 against the Maester Packs design
> ([maester-packs-design.md](maester-packs-design.md), draft PR #2358) and the Microsoft Zero Trust Assessment
> at commit `fa6ffc8` of [microsoft/zerotrustassessment](https://github.com/microsoft/zerotrustassessment)
> (module version 2.6.0). The owner ruled on 2026-10-19 that the pack ships with Maester and is opt-in.

## 1. Summary

Maester ships an official pack, `maester.zero-trust-assessment`, that runs Microsoft's Zero Trust Assessment
(ZTA) and shows each of its results as a Maester result row, `MP.MAES.ZTA.<ZTA test ID>`. It lives in
`packs/zero-trust-assessment/`. It does not copy ZTA's code: it runs the `ZeroTrustAssessment` module the user
installs, or reads a report ZTA already wrote.

- **One family test.** The pack is a single 3.0 native test, `MP.MAES.ZTA`, whose instance source gets ZTA's
  report and returns one instance per result. Families already exist in 3.0, so the pack runs on today's engine
  as a custom test (`Invoke-MtTest -Path packs/zero-trust-assessment/tests`) and needs nothing from the pack
  loader beyond loading its one file.
- **Opt-in through `LongRunning`.** The family is `LongRunning`, so `Invoke-Maester` leaves it out unless the
  run names `MP.MAES.ZTA`, sets `-IncludeLongRunning`, or turns either on in config. Its timeout is
  `Execution.LongRunningTimeoutSeconds`.
- **Import or collect.** With `GlobalSettings."ZeroTrustAssessment.ReportPath"` set, the pack reads that report
  (the recommendation for CI). Without it, the pack runs ZTA in a child `pwsh` process and reads the report it
  writes.
- **A static catalog.** `catalog.json`, generated from the module by `build/zta/Update-MtZtaCatalog.ps1`, lists
  the 336 tests with title, pillar, risk level, impact, cost, service and licence, for the pack's listing.

## 2. What the Zero Trust Assessment is

ZTA is Microsoft's PowerShell module (MIT licence) that rates a Microsoft 365 tenant against its Zero Trust
guidance. 3.0 borrowed its test model, so the two are close:

| | ZTA | Maester 3.0 |
| --- | --- | --- |
| A test | `Test-Assessment.<id>.ps1` with `[ZtTest(...)]` + `.md` | `Test.<ID>.ps1` with `[MaesterTest(...)]` + `.md` |
| Rating | `RiskLevel`, `UserImpact`, `ImplementationCost`, `Pillar`, `Category`, `SfiPillar` | `Severity`, `UserImpact`, `ImplementationCost`, `Product`, `Feature`, `Area` |
| Gates | `Service` (all-of), `CompatibleLicense`, `TenantType` | `Service`, `License`, `TenantType` |
| Result helper | `Add-ZtTestResultDetail` | `Add-MtTestResultDetail` |
| Statuses | Passed, Failed, Investigate, Skipped, Error, Planned | Passed, Failed, Investigate, Skipped, Error, NotRun |

The difference that decides the integration is how ZTA gets its data. `Invoke-ZtAssessment` runs in stages:
export the tenant's data (Graph, Azure, Exchange, Security & Compliance, SharePoint, AIP) into JSON files, load
them into a DuckDB database, run every test against the database with `-Database`, then write
`zt-export/ZeroTrustAssessmentReport.json` and an HTML report. The tests cannot run without the export and the
database, and the module carries native DuckDB binaries, PSFramework, and exact pins on the Graph, Exchange
Online and Az modules, which it downloads into its own cache and loads in a fixed MSAL order.

## 3. Options considered

| Option | What it means | Verdict |
| --- | --- | --- |
| Port the tests to Maester | Rewrite 336 tests against `Invoke-MtGraphRequest` | No: they query ZTA's database, and two copies would drift |
| One Maester test per ZTA test, calling ZTA in-process | Generated `Test.MP.MAES.ZTA.<id>.ps1` files that call ZTA's private test functions | No: needs ZTA's private functions and database, and ZTA's pinned modules cannot share a process with Maester's |
| **Run ZTA, map its report** | Run `Invoke-ZtAssessment` (or read its output) and turn each report row into a Maester row | **Chosen**: uses only ZTA's public commands and its report, which is versioned data |

Within the chosen option, the report is mapped by a family test rather than 336 generated test files. A
family runs its instance source once under its own timeout, which is exactly the "collect once, then report
many" shape ZTA needs, and it works on the 3.0 engine today. The Collect hook in the packs overview's
"Under discussion" section would give the same shape to generated per-test files; if it lands, the pack can
move to it without changing the result IDs.

## 4. How it runs

### 4.1 Import

`ZeroTrustAssessment.ReportPath` names `ZeroTrustAssessmentReport.json`, the folder passed to
`Invoke-ZtAssessment -Path`, or its `zt-export` folder. The pack refuses, with a skip reason on the family:

- a report for another tenant than the Graph connection (`TenantId` differs from `Get-MgContext`);
- a report older than `ZeroTrustAssessment.MaxReportAgeDays` (default 7, `0` turns it off);
- a file that is missing or has no `Tests` list.

Import is text only: no ZTA code runs in the Maester process.

### 4.2 Collect

Without a report path, the pack needs `ZeroTrustAssessment` installed (Maester never installs it; the skip
reason says how). It starts the newest installed version in a child `pwsh -NoProfile` process:

1. Writes a request file with the `Connect-ZtAssessment` and `Invoke-ZtAssessment` parameters, so no setting
   reaches a command line.
2. Signs the child in with `Connect-ZtAssessment`: to Maester's tenant; with Maester's app and certificate when
   Maester is connected app-only with a certificate; interactively otherwise. `ZeroTrustAssessment.Connect`
   adds or overrides parameters.
3. Runs `Invoke-ZtAssessment -NoBrowser` with `Pillar`, `Tests` and `Days` from settings, telemetry off unless
   `ZeroTrustAssessment.DisableTelemetry` is `false`, and Maester's `EmergencyAccessAccounts` passed through ZTA's
   configuration file (both tools use the same shape).
4. Waits in one-second steps, so a Maester timeout or Ctrl+C stops it, and kills the child if the run stops.
5. Reads the report as in Import. The output goes to a new temporary folder that is deleted afterwards,
   because the export is raw tenant data, unless `ZeroTrustAssessment.OutputPath` is set.

The child process is why the pack's Graph scopes do not touch `Connect-Maester`: the child signs in with ZTA's
own scopes. It also means an interactive user signs in twice; CI should use Import or an app with a certificate.

### 4.3 Mapping

| ZTA | Maester |
| --- | --- |
| `TestId` | Instance suffix: `MP.MAES.ZTA.<TestId>`. A repeated ID (the Defender for Cloud rows) gets `.<first 10 hex of SHA-256 of the title>`; exact repeats get `.2`, `.3` |
| `TestTitle` | Instance `Title` |
| `TestRisk` High, Medium, Low | Instance `Severity`; `Unranked` leaves it to config |
| `TestPillar` | Tags `ZeroTrust` and `ZeroTrust.<pillar>` |
| `TestDescription`, `TestResult` | `Add-MtTestResultDetail -Description -Result` |
| Passed, Failed | `$true`, `$false` |
| Investigate | `-Investigate`, `$true` |
| Skipped | Maester's own skip code where both tools have it (`NotApplicable`, the licence and connection codes), else `Custom` with ZTA's reason |
| Error, or a status the pack does not know | `-SkippedBecause Error` with ZTA's result |
| Planned (`UnderConstruction`) | Left out |

Results are taken for every ID in the report, not only the IDs in `catalog.json`, so a test added in a newer
ZTA release is reported before the catalog is regenerated. ZTA is Microsoft's code running with the user's own
consent, so the "results only for catalog IDs" rule for module packs adds nothing here.

## 5. What it needs from the packs implementation

The pack follows the manifest of section 4.2 of the packs design and runs on the 3.0 engine, so it can land
before the loader. These are the points where the loader decides how it ships:

1. **Bundled packs.** Where official packs that ship with Maester live in the module (proposed: `packs/` in the
   module folder, copied by the build), and that they are found without `Install-MtPack` or a lock file entry,
   their integrity being the module's own.
2. **Selection.** `-Suite MAES.ZTA` should select a long-running family the way an exact `-TestId` does, so
   "turn the pack on" is one switch. Today only an exact ID or `-IncludeLongRunning` lifts `LongRunning`.
3. **The report's Packs section** should group the family's rows under the pack, with ZTA's pillar as a
   sub-group (the `ZeroTrust.<pillar>` tag).
4. **`Uses.Modules`** with `"Install": "User"` and `"Process": "Child"` is new: the module is never saved by
   Maester and never loaded in its process. The manifest schema needs both keys, or a different way to say it.
5. **`Catalog`** is a new manifest key for a static test list when a pack's tests are a family.

## 6. Open questions

- Whether Maester's own headline score should count ZTA rows (the packs design keeps pack rows out of it).
- How `Investigate` rows from ZTA (17 of 820 in Microsoft's sample report) count in the pack's pass rate.
- Overlap: Maester's MT checks and ZTA rate some of the same Entra and Intune settings (the attribute rubric
  already cross-references ZTA). A later version could link the overlapping IDs.
