# Maester Module Optimization Plan

This document describes a set of targeted build-time and structural optimizations for the
`maester365/maester` repository. The goal is to reduce `Import-Module` time, reduce Pester
test discovery time, and reduce the installed file count — without changing any user-facing
behavior or removing bundled tests.

All changes are **build-time transformations only**. The source tree stays as individual files
for developer ergonomics. The published artifact changes.

---

## Guiding Principles

- Source files are never modified directly by the build optimizations.
- The published module must be functionally identical to the current one.
- `Custom/` test folder is never touched by any build step.
- Load order (internal before public) must be explicitly enforced, not assumed.
- Base classes must always be defined before derived classes in consolidated output.

---

## Coding Standards

All PowerShell files created or modified as part of this project — including the build script,
any updated module functions, and any new helper scripts — must conform to the following
standards. These apply to new code and to any code that is substantively modified. They are
not retroactively enforced on untouched files in a single pass, but the style pass in Item 1
is an appropriate opportunity to correct obvious violations encountered along the way.

| Standard | Rule |
| --- | --- |
| Brace style | One True Brace Style (OTBS). Opening brace on the same line as the statement. |
| Casing | Pascal Case for all variable names, parameter names, and object properties. |
| Indentation | 4 spaces. No tabs. |
| Encoding | UTF-8 with BOM (`utf8BOM`) for all `.ps1` and `.psm1` files. |
| Function verbs | Approved PowerShell verbs only (`Get-Verb` is the authoritative list). |
| Trailing whitespace | No trailing spaces on any line. |
| Final newline | One blank line at the end of every file. |

**OTBS example:**

```powershell
function Invoke-MaesterBuild {
    [CmdletBinding()]
    param (
        [string] $OutputPath
    )

    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
    }
}
```

---

## 1. Move Comment-Based Help Inside Function Bodies

**Status:** Required prerequisite for Item 2. Must be completed first.

**Problem:** Many `.ps1` files in `powershell/public/` and `powershell/internal/` have
comment-based help placed *above* the `function` keyword rather than inside the function body.
When files are concatenated during consolidation, an intervening blank line between `#>` and
`function` silently breaks `Get-Help` with no error or warning.

**Action:**

- For every `.ps1` file under `powershell/public/` and `powershell/internal/`, move the
  comment-based help block from above the `function` keyword to inside the function body,
  immediately after the opening brace and before `[CmdletBinding()]`.

**Before:**

```powershell
<#
.SYNOPSIS
    Gets a role.
#>
function Get-MtRole {
    [CmdletBinding()]
    param ()
}
```

**After:**

```powershell
function Get-MtRole {
    <#
    .SYNOPSIS
        Gets a role.
    #>
    [CmdletBinding()]
    param ()
}
```

**Scope:** All `.ps1` files in the repository, including `powershell/public/`,
`powershell/internal/`, `powershell/core/`, `build/`, `tests/`, and `maester-tests/`.
This is a project-wide style consistency pass, not just a prerequisite for consolidation.

The only files exempt from this change are standalone scripts that contain no function
definitions — files where there is no function body to move help into. These are expected
to be rare. Identify them during the pass and note them for individual review.

**Verification:** After moving help blocks, run `Get-Help <FunctionName>` for a representative
sample of functions and confirm help is returned correctly.

---

## 2. Consolidate Function Files Into a Single PSM1

**Status:** Confirmed. Highest impact optimization.

**Problem:** The current `Maester.psm1` dot-sources hundreds of individual `.ps1` files at
import time using `Get-ChildItem` loops. Each file is a separate filesystem read. On slower
storage or cold-cache environments this is the dominant cost of `Import-Module Maester`.

**Action:**

- During the build, concatenate all `.ps1` files from `powershell/internal/` and
  `powershell/public/` into a single `Maester.psm1` in the output directory.
- Internal files must be written first (public functions may call internal helpers).
- Within each folder, sort files to ensure deterministic output across platforms (Windows and
  Linux runners may return different filesystem orders).
- Exclude any file matching `*.Tests.ps1` from consolidation.
- Exclude the `build/` directory entirely.

**Load order:**

1. `powershell/internal/**/*.ps1` (sorted by full path)
2. `powershell/public/**/*.ps1` (sorted by full path)

**Implementation notes:**

- Use `[System.Text.StringBuilder]` for efficient string concatenation.
- Write the output file with `-Encoding utf8BOM` to match the encoding convention of all other
  PowerShell files in the project.
- This step depends on Item 1 (comment-based help inside function bodies) being complete.

**Example build logic:**

```powershell
$InternalFiles = Get-ChildItem -Path "$SourceRoot/internal" -Filter '*.ps1' -Recurse |
    Where-Object { $_.Name -notlike '*.Tests.ps1' } |
    Sort-Object -Property FullName

$PublicFiles = Get-ChildItem -Path "$SourceRoot/public" -Filter '*.ps1' -Recurse |
    Where-Object { $_.Name -notlike '*.Tests.ps1' } |
    Sort-Object -Property FullName

$Builder = [System.Text.StringBuilder]::new()
foreach ($File in ($InternalFiles + $PublicFiles)) {
    $null = $Builder.AppendLine((Get-Content -Path $File.FullName -Raw))
}
Set-Content -Path $OutputPsm1 -Value $Builder.ToString() -Encoding utf8BOM
```

---

## 3. Auto-Generate FunctionsToExport in the Module Manifest

**Status:** Confirmed. Low effort, keeps the manifest accurate automatically.

**Problem:** The `FunctionsToExport` array in `Maester.psd1` is already explicitly populated
(good), but it is maintained by hand. As functions are added or removed, this list can drift.

**Action:**

- Parse each `.ps1` file under `powershell/public/` using the PowerShell AST to extract
  top-level function names.
- Overwrite the `FunctionsToExport` array in the output `Maester.psd1` with the extracted
  list.
- Never parse `powershell/internal/` files for exports — internal helpers must not appear
  in `FunctionsToExport` regardless of how they are defined.

**Why the AST, not regex:**
A `^function` regex cannot distinguish between a top-level function and a nested helper
function defined inside another function. Both match the same pattern. The PowerShell AST
exposes the parent node of every `FunctionDefinitionAst`, making it possible to filter
precisely to top-level definitions only.

A nested function's parent chain passes through another `FunctionDefinitionAst`. A
top-level function's parent chain goes directly to the root `ScriptBlockAst`. Filter on
this distinction:

```powershell
foreach ($File in $PublicSourceFiles) {
    $Ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $File.FullName, [ref]$null, [ref]$null
    )

    $TopLevelFunctions = $Ast.FindAll({
        param ($Node)
        $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $Node.Parent -is [System.Management.Automation.Language.ScriptBlockAst] -and
        $Node.Parent.Parent -is [System.Management.Automation.Language.ScriptBlockAst] -and
        $Node.Parent.Parent.Parent -eq $null
    }, $false)

    foreach ($Function in $TopLevelFunctions) {
        # Validate: warn if function name does not match the filename
        $ExpectedName = $File.BaseName
        if ($Function.Name -ne $ExpectedName) {
            Write-Warning "Function name '$($Function.Name)' does not match filename '$($File.Name)'"
        }
        $ExportList.Add($Function.Name)
    }
}
```

**Validation during parsing:**

- **Filename/function name mismatch:** Emit a `Write-Warning` for any file where the
  top-level function name does not match the filename. Treat as a warning, not a build
  error — mismatches may be intentional in some cases.
- **Multiple top-level functions per file:** Emit a `Write-Warning` if a public file
  defines more than one top-level function. Only the intended public function should be
  top-level; any helpers should be nested inside it.
- **Naming convention:** Optionally validate that each exported function name uses an
  approved PowerShell verb (`Get-`, `Test-`, `Invoke-`, etc.) using
  `Get-Verb | Select-Object -ExpandProperty Name`.

**Implementation notes:**

- Parse source files before concatenation (Item 2), not from the merged `.psm1`.
- Use `Update-ModuleManifest` or direct string replacement to update the `.psd1`.
- Sort the exported function list alphabetically for deterministic, diff-friendly output.

---

## 4. Consolidate ORCA Class Files

**Status:** Confirmed.

**Problem:** The ORCA integration uses a class-based architecture (`ORCACheck`,
`ORCACheckConfig`, etc.) defined across multiple `.ps1` files in
`powershell/internal/orca/`. These are loaded via `ScriptsToProcess` in the module manifest,
which runs them in the caller's scope before the module body executes. Multiple files means
multiple filesystem reads at the earliest possible point in the import sequence.

**Action:**

- During the build, consolidate all ORCA class definition files from
  `powershell/internal/orca/` into a single `OrcaClasses.ps1` in the output directory.
- Update `ScriptsToProcess` in the output `Maester.psd1` to reference only the single
  consolidated file.

**Critical constraint — class inheritance order:**
PowerShell requires base classes to be defined before derived classes in the same script
scope. The build step must explicitly enforce load order, not rely on filesystem sort order.

Determine the required order by inspecting class inheritance relationships:

1. Any class with no base class (e.g., `ORCACheckConfig`) comes first.
2. Base classes (e.g., `ORCACheck`) before classes that inherit from them.
3. Helper/enum types before the classes that use them.

**Verification:** After consolidation, run a representative set of ORCA tests
(`Test-ORCA100`, `Test-ORCA143`, etc.) and confirm they pass without class resolution errors.

**Note:** Do not consolidate the ORCA class files into the main `Maester.psm1`. They must
remain in `ScriptsToProcess` (or equivalent) because PowerShell classes defined inside a
module are not accessible to Pester test scripts running in a separate scope.

---

## 5. Consolidate Pester Test Suites Into Per-Suite Files

**Status:** Confirmed.

**Problem:** Each test suite (CISA, CIS, EIDSCA, Maester, ORCA) ships as dozens or hundreds
of individual `*.Tests.ps1` files. Pester performs a filesystem discovery pass at the start
of every `Invoke-Maester` run. Hundreds of individual files means hundreds of filesystem
reads before a single test executes.

**Action:**

- During the build, consolidate each suite folder into a single `*.Tests.ps1` file.
- Use an explicit allowlist of known suite folders. Never use a catch-all glob.
- The `Custom/` folder must never be touched.

**Suite consolidation map:**

| Source folder | Output file |
|---|---|
| `tests/CISA/` | `maester-tests/CISA.Tests.ps1` |
| `tests/CIS/` | `maester-tests/CIS.Tests.ps1` |
| `tests/EIDSCA/` | `maester-tests/EIDSCA.Tests.ps1` |
| `tests/Maester/` | `maester-tests/Maester.Tests.ps1` |
| `tests/ORCA/` | `maester-tests/ORCA.Tests.ps1` |
| `tests/Custom/` | Copied as-is. No consolidation. |

**Implementation notes:**

- Sort input files by full path before concatenation for deterministic output.
- Each individual `*.Tests.ps1` file is a self-contained set of `Describe`/`It` blocks.
  Pester does not care how many `Describe` blocks are in a single file.
- Tag filtering (`-Tag`, `-ExcludeTag`) operates at the `Describe`/`It` level and is
  unaffected by file consolidation.

**Impact on `Update-MaesterTests`:**
The `Update-MaesterTests` function currently overwrites individual test files. After this
change it should download and overwrite the consolidated suite files instead. This must be
updated in the `Update-MaesterTests` implementation to match the new output structure.

---

## 6. Add Build-Time Profiling Step

**Status:** Tentative.

**Rationale:** Without measurement, it is difficult to validate that the optimizations above
produce meaningful improvement, or to catch regressions in future releases.

**Proposed action:**

- Add an optional `-Profile` switch to the build script.
- When set, the build script measures `Import-Module` time and `Invoke-Maester` discovery
  time for both the pre-optimization and post-optimization output, and writes a summary.

```powershell
$PreOptimization = Measure-Command { Import-Module ./output/pre/Maester.psd1 -Force }
$PostOptimization = Measure-Command { Import-Module ./output/post/Maester.psd1 -Force }
Write-Host "Import time before: $($PreOptimization.TotalSeconds)s"
Write-Host "Import time after:  $($PostOptimization.TotalSeconds)s"
```

---

## 7. Create a Consolidated Build Script

**Status:** Confirmed.

**Location:** `./build/Build-MaesterModule.ps1`

**Purpose:** A single, self-contained PowerShell build script that executes all consolidation
and optimization steps in the correct order and writes the publishable module artifact to
`./module/`. This script is the authoritative entry point for producing the published module.
It replaces any ad-hoc or inline build logic that currently exists in the workflow files.

**Script responsibilities (in execution order):**

1. Clean and recreate the `./module/` output directory.
2. Parse public source files with the AST and collect the `FunctionsToExport` list,
   emitting warnings for any naming violations (Item 3).
3. Consolidate `powershell/internal/` and `powershell/public/` `.ps1` files into
   `./module/Maester.psm1` (Item 2).
4. Consolidate ORCA class files into `./module/OrcaClasses.ps1` in their required
   inheritance order (Item 4).
5. Copy and update `Maester.psd1` to `./module/Maester.psd1`, writing the auto-generated
   `FunctionsToExport` list and updating `ScriptsToProcess` to reference `OrcaClasses.ps1`
   (Items 3 and 4).
6. Consolidate each test suite into a single `*.Tests.ps1` file under
   `./module/maester-tests/` (Item 5).
7. Copy `tests/Custom/` to `./module/maester-tests/Custom/` without modification.
8. Copy static assets (`assets/`, `Maester.Format.ps1xml`, `README.md`) to `./module/`.
9. If the `-Profile` switch is provided, measure and report `Import-Module` time for the
   output module (Item 6).

**Parameters:**

```powershell
param (
    [string] $SourceRoot  = "$PSScriptRoot/../powershell",
    [string] $TestsRoot   = "$PSScriptRoot/../tests",
    [string] $OutputRoot  = "$PSScriptRoot/../module",
    [switch] $Profile
)
```

**Output directory structure:**

```text
./module/
├── Maester.psd1               # updated manifest (auto-generated FunctionsToExport)
├── Maester.psm1               # consolidated internal + public functions
├── Maester.Format.ps1xml      # copied unchanged
├── OrcaClasses.ps1            # consolidated ORCA class definitions
├── assets/                    # copied unchanged
├── README.md                  # copied unchanged
└── maester-tests/
    ├── CISA.Tests.ps1         # consolidated from tests/CISA/
    ├── CIS.Tests.ps1          # consolidated from tests/CIS/
    ├── EIDSCA.Tests.ps1       # consolidated from tests/EIDSCA/
    ├── Maester.Tests.ps1      # consolidated from tests/Maester/
    ├── ORCA.Tests.ps1         # consolidated from tests/ORCA/
    └── Custom/                # copied from tests/Custom/ unchanged
```

**On committing build output:**
The `./module/` directory must not be committed to the main source branch. Doing so would
cause every PR touching any source file to produce a secondary diff in the consolidated
`Maester.psm1`, making code review noisy and creating the possibility of merge conflicts in
the built artifact even when the underlying source files do not conflict.

Instead, the CI/publish workflow should attach the built `./module/` directory as a zipped
artifact on each GitHub Release. This satisfies both goals without polluting the source
branch:

- Users who want to download the built module directly can do so from the Releases page.
- The PowerShell Gallery publish step reads from `./module/` during the workflow run.

Confirm that `./module/` is listed in `.gitignore`. If it is not, add it as part of PR 4
alongside the workflow changes.

**Coding standards:** The build script itself must conform to all standards listed in the
Coding Standards section above: OTBS, Pascal Case, 4-space indentation, `utf8BOM` encoding,
approved verbs, no trailing whitespace, one trailing blank line.

---

## 8. Update GitHub Actions Workflows

**Status:** Confirmed.

**Location:** `./.github/workflows/`

**Problem:** The existing build and publish workflows either inline build logic or reference
steps that are no longer valid after the introduction of the consolidated build script and the
`./module/` output directory.

**Actions:**

**Build/CI workflow** (e.g., `build.yml` or equivalent):

- Replace any inline consolidation or copy steps with a single call to
  `./build/Build-MaesterModule.ps1`.
- Add a step that validates the output `./module/` directory contains the expected files
  before proceeding.
- Add a step that imports `./module/Maester.psd1` and runs `Get-Help` against a
  representative sample of functions to verify comment-based help is intact after
  consolidation.
- Add a step that runs a smoke test by importing the module and calling
  `Get-Command -Module Maester` to confirm the expected function count is exported.

**Publish workflow** (e.g., `publish.yml` or equivalent):

- Publish from `./module/` rather than from `./powershell/` or any other source directory.
- Ensure the publish step runs only after the build step has completed and all validation
  steps have passed.
- Confirm that the `ModuleVersion` in `./module/Maester.psd1` has been correctly stamped by
  the build process before publishing.
- Zip the `./module/` directory and attach it as an artifact on the GitHub Release, so users
  can download the built module directly from the Releases page without installing from
  the PowerShell Gallery.

**General workflow hygiene:**

- Both workflows should check out the repository and invoke `./build/Build-MaesterModule.ps1`
  as the first substantive step, rather than duplicating logic between workflows.
- Add workflow-level comments explaining that `./module/` is a build artifact and should
  never be committed to source control.

---

## 9. Update Documentation and Contributing Guidelines

**Status:** Confirmed.

**Locations:**

- `/.github/CONTRIBUTING.md` — exists; brief entry point only. Update minimally.
- `/website/` — contains the full contributing and development documentation. This is the
  primary location for detailed guidance. Add or update pages here.
- `./README.md` — update the building-locally section if one exists.

### `/.github/CONTRIBUTING.md`

This file should remain brief. Add a short paragraph noting the new build process and
pointing contributors to the full build and development guide in the website docs. Do not
duplicate content here that belongs in the website.

### `/website/` Documentation

This is where the substantive updates belong. Add or update the following:

**Build process / developing locally:**

- Source files live in `./powershell/` and `./tests/`. Never edit files in `./module/`.
- Run `./build/Build-MaesterModule.ps1` to produce the publishable module in `./module/`.
- Always test against the built output in `./module/`, not against `./powershell/` directly.
- `./module/` is a build artifact. It is not committed to source control. Built modules are
  attached to GitHub Releases and published to the PowerShell Gallery from CI.

**Code style (new or updated section):**

- One True Brace Style (OTBS). Opening brace on the same line as the statement.
- Pascal Case for all variable and parameter names.
- 4-space indentation. No tabs.
- UTF-8 with BOM encoding for all `.ps1` and `.psm1` files.
- Approved PowerShell verbs only. Run `Get-Verb` for the authoritative list.
- No trailing whitespace. One blank line at the end of every file.
- Comment-based help must be placed inside the function body, not above the `function`
  keyword. See Item 1 for the correct pattern.

**File organization (new or updated section):**

- Public functions go in `./powershell/public/`. One function per file. Filename must match
  the function name exactly.
- Internal helper functions go in `./powershell/internal/`. These are never exported.
- Pester test suite files go in `./tests/<SuiteName>/`.
- The `FunctionsToExport` list in `Maester.psd1` is auto-generated at build time. Do not
  edit it manually.
- The consolidated test suite files in `./module/maester-tests/` are generated at build
  time. Do not edit them manually.

### `./README.md`

- Confirm the user-facing installation instructions (`Install-Module`, `Install-MaesterTests`,
  `Invoke-Maester`) are unchanged. No user-facing change is introduced by this work.
- Add or update a "Building from source" section pointing to the website docs and noting
  that `./build/Build-MaesterModule.ps1` is the entry point.

---

## Tracking and Project Management

This section describes the recommended approach for tracking this work in GitHub. These are
suggestions for whoever is managing the rollout — they are not tasks for an AI coding agent.

### GitHub Issues

Create one GitHub issue per numbered item in this plan (Items 1–9, plus Item 6 if pursued).
Each issue body can be written directly from the corresponding section of this document.
The PR sequence in the Implementation Order section maps cleanly to issue groupings.

Do not create issues for the "Out of Scope / Explicitly Rejected" items. Those decisions are
documented here and do not require tracking.

### Tracking Issue

Create a single parent tracking issue that:

- Briefly describes the overall optimization effort and links to this plan document.
- Lists each child issue as a task checklist item, checked off as each issue is closed.
- Remains open until all child issues are resolved.

This gives contributors and maintainers a single URL to understand the full scope of the work
and see current progress without needing to query a Milestone or project board.

Example checklist structure:

```
## Maester Module Optimization

Tracking issue for the build-time and structural optimizations described in [the plan](#).

- [ ] #N  Item 1 — Move comment-based help inside function bodies
- [ ] #N  Item 2 — Consolidate function files into a single PSM1
- [ ] #N  Item 3 — Auto-generate FunctionsToExport
- [ ] #N  Item 4 — Consolidate ORCA class files
- [ ] #N  Item 5 — Consolidate Pester test suites
- [ ] #N  Item 7 — Create Build-MaesterModule.ps1
- [ ] #N  Item 8 — Update GitHub Actions workflows
- [ ] #N  Item 9 — Update documentation and contributing guidelines
- [ ] #N  Item 6 — Add -Profile switch to build script (tentative)
```

### GitHub Milestones

A Milestone is appropriate when these items are tied to a specific version release — for
example, "all of this lands in v2.0." At that point, create a versioned Milestone and attach
the relevant issues to it. That decision belongs to the release owner and does not need to be
made now.

A Milestone is not recommended as a substitute for the tracking issue at this stage, because
the work items have a strict dependency chain rather than converging independently toward a
release point. The tracking issue pattern is better suited to linear, sequential work.

---

## Out of Scope / Explicitly Rejected

The following were considered and rejected during planning:

| Idea | Reason rejected |
| --- | --- |
| Remove `Microsoft.Graph.Authentication` from `RequiredModules` | `Connect-Maester` is optional. Automation users never call it. 180+ functions call Graph cmdlets directly and would fail with cryptic errors if the module is not loaded. The performance gain is near zero when the module is already in the session, which covers virtually all real-world usage. |
| Lazy-loading Pester | The team intentionally pins Pester at `0.0.0` in `RequiredModules` to avoid conflicts with the Windows-bundled version. Runtime validation is already in place. |
| Adding Graph response caching | Already implemented via `$Script:`-scoped caches in `Invoke-MtGraphRequest` and `Get-MtExo`. |
| Separating test files from the module package | Rejected in favor of keeping the current single-install user experience. |

---

## Implementation Order

The items above have dependencies and should be implemented in this sequence:

```text
1. Move comment-based help inside function bodies   (one-time source pass, own PR)
        ↓
2. Consolidate internal + public PS1 files into Maester.psm1
3. Auto-generate FunctionsToExport from public source files    (2 and 3 together)
4. Consolidate ORCA class files → update ScriptsToProcess
        ↓
5. Consolidate Pester test suites → update Update-MaesterTests
        ↓
7. Write Build-MaesterModule.ps1 in ./build/        (wraps 2–5 into one script)
        ↓
8. Update GitHub Actions workflows                  (point at ./build/ and ./module/)
        ↓
9. Update README.md, CONTRIBUTING.md, website docs
        ↓
6. (Tentative) Add -Profile switch to build script
```

**Recommended PR sequence:**

| PR | Contents |
| --- | --- |
| PR 1 | Item 1 only — comment-based help move, project-wide. Isolated and reviewable on its own. |
| PR 2 | Items 2, 3, 4, 6, and 7 — build script that produces the consolidated `./module/` output. |
| PR 3 | Item 5 — test suite consolidation and `Update-MaesterTests` runtime update. |
| PR 4 | Item 8 — workflow updates to use `./build/` and publish from `./module/`. |
| PR 5 | Item 9 — documentation and contributing guidelines. |
| PR 6 | Item 6 (tentative) — profiling switch, if pursued. |
