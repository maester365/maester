# Maester 2.3.0 vs 3.0 performance (2026-10-10)

Measured with `build/perf/Measure-MaesterPerformance.ps1`. Every sample runs in a fresh `pwsh` process, with one cold run
(a new module analysis cache) and 3–5 warm runs per scenario, the versions alternating. The tables show
warm medians. Cold runs were within the warm spread for every metric.

**Environment:**

- Apple M5 Max (18 logical CPUs, 128 GB), macOS 27.0.1 arm64, PowerShell 7.6.2 / .NET 10.0.8.
- Maester 2.3.0 from the PowerShell Gallery with Pester 6.2.0 (what `Install-Module Maester` installs today). Pester 5.7.1 was also
  measured and is 2–15% faster for 2.3.
- Maester 3.0.0 built from this branch: "3.0 before" is `54e25a20`, "3.0 after" adds the fixes in `perf: cut the
  fixed cost of Invoke-Maester`.
- Both use Microsoft.Graph.Authentication 2.41.1.
- Module paths were isolated, so the benchmark's dependencies were the only modules visible.
- No tenant connection (`-SkipGraphConnect`), with `-DisableTelemetry -SkipVersionCheck -NonInteractive`. HTML, JSON and Markdown went to a temp folder.

## Results

| Metric (warm median) | 2.3 | 3.0 before | 3.0 after | 2.3 → 3.0 after |
|---|---:|---:|---:|---:|
| Import-Module | 0.57 s | 0.40 s | 0.38 s | **−34%** |
| Discovery: Pester `Run.SkipRun` vs `Get-MtTest` | 1.33 s | 0.44 s | 0.43 s | **−68%** |
| Dry run: `Invoke-Maester` with SkipRun vs `-DryRun` | 5.07 s | 4.48 s | 1.72 s | **−66%** |
| Full run, no tenant | 11.06 s | 4.49 s | 1.70 s | **−85%** |
| Subset run `-Tag CA` | 5.33 s | 4.28 s | 1.54 s | **−71%** |
| Peak RSS, full run | 1,508 MB | 1,212 MB | 381 MB | **−75%** |
| Working set at end, full run | 1,052 MB | 752 MB | 381 MB | −64% |
| Peak RSS, import only | 238 MB | 216 MB | 216 MB | −9% |
| Markdown report generation | 0.76 s | 0.80 s | 0.04 s | −95% |
| HTML report generation | 0.05 s | 0.08 s | 0.10 s | +50 ms |
| JSON generation | 0.035 s | 0.026 s | 0.022 s | −37% |
| JSON results size | 6.33 MB | 2.29 MB | 2.29 MB | −64% |
| HTML / Markdown report size | 2.42 / 4.13 MB | 2.39 / 4.20 MB | 2.39 / 4.20 MB | ≈ same |
| Rows, full run | 737: 85 Error, 5 Failed, 338 Skipped, 309 NotRun | 746: 431 Skipped, 315 NotRun | same | |

Warm timings had a standard deviation of 0.01–0.27 s. Peak memory varied by up to ~290 MB between runs before the fixes,
because it depended on when the GC ran. After the fixes it varies by 10–20 MB.

## What the fixes changed

Before the fixes, 3.0 had a fixed cost of about 4.3 s whatever was selected: a dry run, the CA subset and a full run all took
4.3–4.5 s. A `Trace-Script` (Profiler module) run of the built module showed where it went:

| Cost (inclusive) | Cause | Fix |
|---|---|---|
| 1.41 s | `Write-MtProgress -Force` slept 200 ms on macOS on every call, 8 per run (2.3 had 4), even with `-NonInteractive` or redirected output | Sleep once per session, and only when progress is drawn on a console |
| 1.19 s, ~1 GB peak | `Get-MtMarkdownReport` built the ~4 MB report with `+=`, copying the whole string about 8 times per test. This was already the case in 2.3 | `StringBuilder` |
| ~0.5 s | `ConvertTo-MtNativeRow` → `Get-MtMaesterTestFolderPath` ran `Test-Path`/`Resolve-Path` for each of 751 rows | Resolve once per module |
| 0.23 s | `ConvertTo-MtMaesterResult` filtered every row for every native category (87k scriptblock calls) | Index the rows by block once |
| 0.16 s / 0.21 s | Nested `Where-Object` tag matching in `Resolve-MtNativePlan`; `ForEach-Object` copy in `Get-MtHtmlReport` | Plain loops |

The JSON and Markdown output of a full run are unchanged apart from durations, and all 7,951 module unit tests pass.

What remains of the ~1.3 s step after the fixes: the HTML report (~0.5 s, most of it copying each row without its ErrorRecord),
`Resolve-MtNativePlan` (~0.4 s), `Invoke-MtNativePlan` building rows for NotRun tests (~0.4 s) and `ConvertTo-MtMaesterResult` (~0.3 s).

## Still open

1. **`-DryRun` does almost all the work of a real run**, including every report. If it's meant as a quick "what would run" check,
   it could skip reports unless output was requested.
2. **Connection probing** (fixed after these measurements). The probe took about 2.9 s on the test machine with every
   module installed: Azure 1.4 s and Azure DevOps 0.5 s (each validates a saved sign-in with one network call), Teams
   0.6 s, Exchange Online 0.3 s, SharePoint 0.1 s. The last three were spent auto-loading a module to learn that
   nothing was connected. Their connections only exist inside a session, so `Test-MtConnection` now reports them as
   not connected when the module is not imported, without calling it: about 0.9 s less, and three modules fewer in
   the process. An earlier note here blamed this probe for a 40 s start; that was a misreading of a stale
   `Write-Progress` line, which kept showing "Reading the tenant context" while tests were already running.
3. **Runs with the user's own modules visible** (`-ModulePath Inherit`) took 52.8 s (2.3) vs 47.6 s (3.0 before the fixes). In that environment,
   an installed ADOPS module with a live Azure DevOps session made the AZDO tests actually run, so those runs measured real service calls,
   not engine cost.
4. **Console output** is reviewed separately in `docs/proposals/maester-3.0-console-output.md`.

## Not measured

- Tenant-connected runs.
- A true cold OS file cache (`sudo purge`).
- Windows and Linux. The script supports both: peak memory comes from `/usr/bin/time -v` on Linux and from `PeakWorkingSet64` on Windows.
  On Windows the user module folder can't be hidden, so isolation there is best-effort.

## Reproduce

```powershell
./build/Build-MaesterModule.ps1
./build/perf/Measure-MaesterPerformance.ps1 -Repetitions 5 -PesterVersion 5.7.1, 6.2.0
```

The script writes every sample, summary statistics and the environment to `results-<timestamp>.json` in its work folder
(the system temp folder by default).
