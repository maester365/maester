# Proposal: Maester repository restructure

> **Status: PROPOSAL — no changes have been made.** This document analyzes the current
> layout, inventories every consumer of the paths involved, compares candidate target
> structures, and lays out a phased migration for the recommended one. Drafted
> 2026-07-07; revised same day after maintainer review (corrections in §1.4, revised
> recommendation in §3). The appendices contain *draft* conventions documentation and
> are **not yet ratified**.

Goals (from the maintainer request that prompted this):

- Remove ambiguity — especially the mixing of **framework code** with **suite-specific
  helpers** inside `powershell/internal/` and `powershell/public/`.
- Make it crystal clear where *every* file belongs: framework code, suite helpers, and
  unit tests each get an explicitly named home.
- Align the root `tests/` name with the `maester-tests` name it ships under.
- Separate code, tests, documentation, and CI/build artifacts along community norms.
- Preserve history (`git mv`), keep every phase independently shippable, and rate each
  move **safe** / **needs-deprecation-period** / **breaking**.

---

## 1. Current tree (verified against the working tree, 2026-07-07)

### Top level

| Path | Purpose |
| --- | --- |
| `powershell/` | Module source: `Maester.psd1`, dev loader `Maester.psm1`, `Maester.Format.ps1xml`, `README.md` |
| `tests/` | Maester **security check suites** shipped to end users (not unit tests) |
| `build/` | Build, publish, and generator scripts (`Build-MaesterModule.ps1`, suite generators, Pester configs) |
| `website/` | Docusaurus 3 site for maester.dev (docs, blog, versioned_docs, generator scripts) |
| `report/` | Vite + React + Tailwind app; builds the single-file `ReportTemplate.html` |
| `tools/` | One file: `Save-MaesterOffline.ps1` — an optional **user-facing** script (offline download of Maester + dependencies for gallery-blocked systems); not a build script, no in-repo consumers |
| `TestResults/` | Local unit-test output — untracked, ignored via `.gitignore:43` `[Tt]est[Rr]esult*/` |
| `module/` | Build output (gitignored, never committed) |
| `action/` | Deprecation notice only; the GitHub action moved to `maester365/maester-action` |
| `action.yml` | Legacy root GitHub action definition |
| `assets/` | Repo logo images |
| `.github/` | Workflows, composite action, CODEOWNERS, CONTRIBUTING, templates, skills |
| dot-dirs | `.devcontainer/`, `.vscode/`, plus local agent config (`.claude/`, `.codex/`, `.remember/`) |

### `powershell/` subdirectories

| Path | Purpose |
| --- | --- |
| `powershell/internal/` | ~50 framework-private helpers at the root, **plus** suite subdirs `defender/`, `eidsca/`, `orca/` (~240 `check-ORCA*.ps1` + `orcaClass.psm1`), `xspm/`, and `portal/` (a single framework helper, `Get-MtLinkServicePrincipal.ps1`) |
| `powershell/public/` | Exported framework functions at the root + `core/`, **plus** suite subdirs `cis/`, `cisa/{entra,exchange,spo}`, `eidsca/`, `maester/{aiagent…teams}`, `orca/`, `xspm/` |
| `powershell/assets/` | Runtime assets: `ReportTemplate.html`, email/Teams templates, public suffix list |
| `powershell/examples/` | One file: `multi-tenant-pipeline.yml` (no in-repo consumers) |
| `powershell/tests/` | Module **unit tests**: `pester.ps1` runner, `general/`, `functions/`, and the `smoketests/` fixture consumed by `Invoke-Maester.Tests.ps1`; `test-results/` holds untracked local output |

### `tests/` subdirectories

`Maester/{AIAgent,Azure,AzureDevOps,Defender,Drift,Entra,Exchange,Intune,Teams}`,
`EIDSCA/`, `cis/`, `cisa/{entra,exchange,spo}`, `orca/`, `XSPM/`, `Custom/`
(user extension point, contents gitignored), and `maester-config.json`.

### 1.4 Discrepancies vs. the repository map in AGENTS.md — corrected after review

> AGENTS.md is the root agent context file. At the time of writing it is still named
> `CLAUDE.md`; a separate change renames it to `AGENTS.md` (canonical cross-tool
> context) with a thin `CLAUDE.md` bridge importing it. This proposal uses the
> AGENTS.md name throughout.

- **Retracted:** an earlier draft of this proposal claimed `TestResults/` was
  committed. That was wrong — `git ls-files TestResults/` and
  `git ls-files powershell/tests/test-results/` both return **zero** tracked files;
  `git check-ignore -v` attributes them to `.gitignore:43` (`[Tt]est[Rr]esult*/`) and
  `.gitignore:517` (`test-results`) respectively. AGENTS.md's "gitignored" description
  is **correct**. (The error came from grepping for the substring `testresult`, which
  the bracket-expression pattern on line 43 does not literally contain.)
- **Retracted:** an earlier draft called `powershell/tests/smoketests/` orphaned. It is
  an **active fixture**: `powershell/tests/functions/Invoke-Maester.Tests.ps1:11,67`
  builds its path dynamically (`Split-Path $PSScriptRoot -Parent` + `"smoketests"`)
  and validates the `Smoke_{Error,Skipped,Failed,Success,NotRun}` outcome counts.
  Path searches missed it because the reference is constructed, not a literal.
- Still true — not covered by AGENTS.md: `powershell/tests/smoketests/` and
  `test-results/`, the dot-dirs listed above, `website/diagrams/`, `report/patches/`
  (patch-package), and the sub-suite directories under `tests/Maester/` and
  `tests/cisa/`.
- Everything else in the AGENTS.md map matches the tree.

### Flags / unknowns

- `powershell/examples/multi-tenant-pipeline.yml` and `tools/Save-MaesterOffline.ps1`
  have **zero** in-repo consumers (code, workflows, or website docs). External links
  from blogs or social posts could not be ruled out — treat as low-risk, not zero-risk.
  Mitigating the example's case: its full pipeline YAML is **already embedded** in
  `website/docs/multi-tenant/azure-devops-pipeline.md` (fenced block, lines 103–300),
  so the documented copy survives regardless of what happens to the file.
- CODEOWNERS references `tests/CISA/` but the directory is `tests/cisa/` — a
  pre-existing case mismatch.
- `.gitignore:521` is `module/` **without a leading slash** — it matches a directory
  named `module` at *any* depth, not just the repo root. This is harmless today but
  becomes a trap for the recommended layout (see Phase 4).

---

## 2. Path-consumer inventory

Every consumer verified at the cited file:line. This is the evidence base for the
ratings in sections 3–4.

### 2.1 Root `tests/`

| Consumer | Reference |
| --- | --- |
| `build/Build-MaesterModule.ps1:40` | `$TestsRoot` default `$PSScriptRoot/../tests`; Phase G copies it wholesale to `module/maester-tests/` |
| `.github/workflows/publish-tests.yaml:44,51-52` | Stamps `./tests/maester-config.json`; pushes `source-directory: ./tests` → `target-directory: ./tests` in `maester365/maester-tests` |
| `.github/workflows/build-validation.yaml:34-43` | `dorny/paths-filter` includes `tests/**` in the `pwshmodule` filter gating the whole job |
| `.github/workflows/build-website.yaml` | `tests/**` in its paths filter triggers site rebuild |
| `website/scripts/generate-test-docs.mjs:8,12` | Reads `tests/` and `tests/maester-config.json` to generate `website/docs/tests/` |
| `powershell/public/Invoke-Maester.ps1:285-291` | Dev heuristic: if `./powershell/tests/pester.ps1` exists → `Run.Path = './tests'` (hardcodes **both** paths) |
| `powershell/public/Get-MtTestInventory.ps1:84` | Default `-Path` = `Join-Path $PSScriptRoot '..\..' 'tests'` — hardcodes the repo folder name |
| `build/orca/Update-OrcaTests.ps1` / `build/eidsca/Update-EidscaTests.ps1` | Generators write `tests/orca/` and `tests/EIDSCA/` |
| `.github/CODEOWNERS:5-7` | `tests/Maester/`, `tests/EIDSCA/`, `tests/CISA/` |
| `.gitignore:525` | `tests/Custom/*.ps1` |
| `powershell/public/core/Install-MaesterTests.ps1:9` | Help text links `tree/main/tests` |

**On the `maester365/maester-tests` repository:** per maintainer review it is **not
actively maintained and is not a source of truth** for anything in this repo. It is
noted here only because `publish-tests.yaml` still pushes to it (the workflow's own
comment says it remains in use by the GitHub action and the Azure DevOps starter
guide). The relevant conclusion is destination-independent either way: renaming the
*monorepo* `tests/` folder only changes `source-directory`; whether the push and its
`target-directory` continue to exist is a separate decision, out of scope here.

### 2.2 `powershell/tests/` (unit tests)

| Consumer | Reference |
| --- | --- |
| `.github/workflows/build-validation.yaml:77,88` | Runs `./powershell/tests/pester.ps1` on pwsh and Windows PowerShell |
| `powershell/tests/pester.ps1:26,32,51-52` | Imports `..\Maester.psd1`; writes `..\..\TestResults` (repo root); coverage over `..\public` + `..\internal` |
| `powershell/tests/functions/Invoke-Maester.Tests.ps1:11,67` | Runs `Invoke-Maester` against the sibling `smoketests/` fixture (dynamic path — moves with the tree) |
| `powershell/public/Invoke-Maester.ps1:287` | `Test-Path './powershell/tests/pester.ps1'` is the "am I in the dev repo" sentinel — load-bearing |
| `.github/pull_request_template.md:17`, `.github/skills/maester-test-expert/SKILL.md:761`, `website/docs/contributing.md` (+ versioned copy) | Instruct contributors to run `./powershell/tests/pester.ps1` |
| `powershell/tests/functions/Get-MtHtmlReport.Tests.ps1:4-5` | Loads `../../assets/ReportTemplate.html` |

### 2.3 `powershell/internal/` and `powershell/public/` (suite subdirs)

| Consumer | Reference |
| --- | --- |
| `powershell/Maester.psm1:35-36` | Dev loader dot-sources **recursively** — subdirectory names and depth are irrelevant to it |
| `build/Build-MaesterModule.ps1:268,285` | `Get-RelativeDepth` + `Resolve-ConsolidatedPaths` strip `../` × each file's depth automatically during flattening — deeper nesting needs **no build change**, but a moved file's own `$PSScriptRoot/../` literals must match its new dev-time depth |
| `build/Build-MaesterModule.ps1:566,579` | Hardcodes `internal/orca/orcaClass.psm1` and globs `$SourceRoot/internal/orca` for `check-ORCA*.ps1` |
| ~240 × `internal/orca/check-ORCA*.ps1` (line 3 each) | `using module ".\orcaClass.psm1"` — same-directory reference; safe if the directory moves **wholesale**, broken if split |
| `build/orca/Update-OrcaTests.ps1` | Regenerates files into `powershell\internal\orca\` and emits the `using module` line |
| `build/eidsca/Update-EidscaTests.ps1:22` | Reads `powershell/internal/eidsca/` |
| `build/Update-CommandReference.ps1:20,29` | **Non-recursive** `Get-ChildItem @("./powershell/internal", "./powershell/internal/orca")` for doc exclusions; sets docs `EditUrl` base to `blob/main/powershell/public/` |
| `website/scripts/generate-test-docs.mjs` | Walks `powershell/public` and `powershell/internal` (specifically `internal/eidsca`) for source links embedded in generated docs |
| Hand-written docs | `website/docs/writing-tests/formatting-test-results.md:126`, `advanced-concepts.md:71` deep-link `blob/main/powershell/{public,internal}/...` |

**`$PSScriptRoot` literal census** (re-verified by grep across `internal/*.ps1` and
`public/*.ps1`): three internal-root files — `Get-MtMaesterTestFolderPath.ps1:2`
(`../maester-tests`, the installed-module contract), `Get-MtMarkdownReport.ps1:115`
(`../assets/...`), `Show-MtLogo.ps1:7` (`../Maester.psd1`) — and four public-root
files — `Get-MtRegistrableDomain.ps1:50`, `Send-MtMail.ps1:78`,
`Send-MtTeamsMessage.ps1:89` (all `../assets/...`), `Get-MtTestInventory.ps1:84`
(`'..\..' 'tests'`). `public/core/Get-MtHtmlReport.ps1:56` already uses `../../assets`
(depth 2). **No file inside a suite subdirectory carries such a literal**, so moving
suite directories deeper requires zero literal rewrites; moving the *framework* files
one level deeper requires exactly these seven edits.

`internal/portal/` is referenced by nothing (loaded only via the recursive dot-source);
its single file is a framework helper, not a suite helper.

### 2.4 Other paths

| Path | Consumers |
| --- | --- |
| `powershell/assets/` | Build copies it to `module/assets` (`Build-MaesterModule.ps1:620-623`); five runtime functions reference it via depth-encoded literals (census above); `Test-MaesterModuleOutput.ps1` asserts it exists in output |
| `module/` (output) | `Test-MaesterModuleOutput.ps1` asserts `Maester.psd1/psm1`, `OrcaClasses.ps1`, `Maester.Format.ps1xml`, `assets/`, `maester-tests/Custom`; installed runtime resolves bundled suites via `Get-MtMaesterTestFolderPath` → `<module>/maester-tests` — **output-side names are frozen contracts** |
| `TestResults/` (root) | Created at run time by `pester.ps1`; uploaded/read by `build-validation.yaml:86,104,142,148`; ignored by `.gitignore:43` |
| `powershell/examples/`, `tools/` | No consumers found anywhere in the repo or website; the example's YAML is already duplicated inside `website/docs/multi-tenant/azure-devops-pipeline.md` |
| `.vscode/launch.json:11` | Imports `${workspaceFolder}/powershell/Maester.psd1` |
| `.gitignore:521,532` | `module/` (no leading slash — matches at any depth) and `powershell/maester-tests` |
| `maester-action` repo | **No path coupling** to this monorepo's layout (it checks out the *consumer's* repo and uses its own `public-tests` convention) |

---

## 3. Candidate target structures

### Candidate A — Conservative hygiene

Rename `tests/` → `maester-tests/`, relocate the orphaned example and tool, fold
`internal/portal/` into `internal/`. **No change** to the internal/public suite mixing
and no explicit framework home — the core ambiguity remains.

### Candidate B — Explicit homes for everything (**recommended**, revised after maintainer review)

Every file class gets a named directory: framework code in `framework/`, suite helpers
in `suites/`, the module itself in `module/`, unit tests in `unit-tests/`:

```text
maester/
├── powershell/
│   ├── module/                              # ← the PowerShell module, complete
│   │   ├── Maester.psd1 / Maester.psm1      #   (loader unchanged — recursive)
│   │   ├── Maester.Format.ps1xml
│   │   ├── assets/
│   │   ├── internal/
│   │   │   ├── framework/                   # framework-private helpers (~50 files
│   │   │   │                                #   + Get-MtLinkServicePrincipal.ps1 from portal/)
│   │   │   └── suites/                      # private helpers per test suite
│   │   │       ├── defender/  eidsca/  xspm/
│   │   │       └── orca/                    # orcaClass.psm1 + check-ORCA*.ps1, wholesale
│   │   └── public/
│   │       ├── framework/                   # exported framework surface
│   │       │                                #   (absorbs root files + old public/core/)
│   │       └── suites/
│   │           ├── cis/  cisa/  eidsca/  orca/  xspm/
│   │           └── maester/ (aiagent/ … teams/)
│   ├── unit-tests/                          # ← renamed from powershell/tests
│   │   ├── pester.ps1
│   │   └── functions/  general/  smoketests/
│   └── tools/                               # ← moved from /tools; optional user-facing
│       └── Save-MaesterOffline.ps1          #   scripts that live outside the module
├── maester-tests/                           # ← renamed from tests/ (one tree, unchanged inside)
├── build/    website/    report/    .github/
```

Maintainer decisions baked in: the framework tier is named **`framework`** (preferred
over reusing `core`; the delta is one extra `git mv` of `public/core/` →
`public/framework/` plus two config touch-ups, since command docs regenerate anyway),
and unit tests are **separated from code** via the `module/` + `unit-tests/` split
rather than staying at `powershell/tests/`.

### Candidate C — Full `src/` alignment

`src/maester/framework|suites/...`, unit tests to `tests/unit/`. Candidate B now
delivers C's actual clarity wins (explicit framework/suites/tests homes) while keeping
the `powershell/` root that contributor muscle memory, workflow path filters, and
hundreds of historical doc links already use. C's remaining delta — the literal `src/`
name — still costs a whole-tree rebase for every open PR. Rejected.

### Comparison

| Dimension | A | B (recommended) | C |
| --- | --- | --- | --- |
| Solves framework-vs-suite ambiguity (core goal) | No | **Yes** | Yes |
| Explicit home for every file class | No | **Yes** | Yes |
| Code/tests separation under the source root | No | **Yes** | Yes |
| `tests/` naming aligned with shipped `maester-tests` | Yes | Yes | Yes |
| Loader / build-enumeration changes | none | SourceRoot only | rewrite |
| `$PSScriptRoot` literal rewrites | 1 (rename-related) | **7** (census, §2.3) | 8+ |
| Contract risk (installed users, module output) | none | none | none, if careful |
| Open-PR rebase pain | low | medium-high (most of `powershell/`) | severe |
| Migration effort | S | **M/L, amortized over 4 phases** | L |

### Design tensions, resolved explicitly

1. **Suite check files stay in ONE `maester-tests/` tree** rather than co-located under
   each `powershell/module/**/suites/<suite>/`. Three consumers treat the tree as a
   unit: the build copies `TestsRoot` wholesale, `publish-tests.yaml` pushes one
   `source-directory`, and `generate-test-docs.mjs` walks one root. Splitting it would
   force the build to reassemble the shipped tree — and would recreate the very
   ambiguity ("are these unit tests?") inside the module source. Suite ownership stays
   legible via CODEOWNERS entries on `maester-tests/<Suite>/`.
2. **Unit tests: separated, but kept module-adjacent.** An earlier draft recommended
   leaving them at `powershell/tests/`. Maintainer review preferred explicit
   separation; the `powershell/{module,unit-tests}` split achieves it while keeping
   the tests next to what they test. The costs are bounded and enumerated in Phase 4 —
   including a `.gitignore` trap found during review: line 521's `module/` (no leading
   slash) would silently ignore `powershell/module/` and must become `/module/` in the
   same change.

---

## 4. Phased migration plan (Candidate B)

Every phase is independently shippable; all moves use `git mv` to preserve history.
Ratings: **safe** = no user-visible or external effect; **needs-deprecation-period** =
old behavior kept working for a window; **breaking** = external contract change (none
are proposed).

**Non-issues confirmed during review (no phase needed):** `TestResults/` and
`powershell/tests/test-results/` are already ignored and untracked;
`powershell/tests/smoketests/` is an active fixture and simply moves with the
unit-test tree in Phase 4.

### Phase 1 — Orphans · rating: **safe** · effort: S

1. `git mv powershell/examples/multi-tenant-pipeline.yml docs/examples/` — keep the
   sample as a standalone, tracked example rather than deleting it. A near-equivalent
   copy is already embedded as a fenced code block in
   `website/docs/multi-tenant/azure-devops-pipeline.md` (lines 103–300), but the two
   have **drifted**: the standalone retains an Azure DevOps/ADOPS integration path the
   docs page omits, while the docs page adds per-tenant disconnects the standalone
   lacks. Preserving the file under `docs/examples/` avoids losing that content. This
   introduces a repo-root `docs/examples/` landing zone for standalone example
   artifacts — distinct from the Docusaurus site under `website/`, which continues to
   embed pipeline samples as fenced blocks in `.md` pages (the docs plugin only routes
   `.md`/`.mdx`; a raw downloadable file, if ever wanted *on the site*, would belong in
   `website/static/`, not `website/docs/`).
2. `git mv tools powershell/tools` — `Save-MaesterOffline.ps1` is an optional
   **user-facing** script, not a build script, so `build/` is the wrong home; parking
   it under `powershell/` groups it with the rest of the PowerShell deliverables and
   anticipates the Phase 4 layout (`powershell/{module, unit-tests, tools}`). Safety:
   the module build never globs it (`Build-MaesterModule.ps1` enumerates only
   `$SourceRoot/internal`, `$SourceRoot/public`, `assets/`, and the format file), the
   unit-test PSScriptAnalyzer pass only scans `public/` + `internal/`, and the
   repo-wide `psscriptanalyzer.yml` CI scan covers it in either location.

### Phase 2 — Framework/suites separation · rating: **safe** (shipped output unchanged) · effort: M

1. Moves (wholesale directories and root files, `git mv`):
   - `powershell/internal/{defender,eidsca,orca,xspm}` → `powershell/internal/suites/`
   - `powershell/internal/*.ps1` (root files) → `powershell/internal/framework/`
   - `powershell/internal/portal/Get-MtLinkServicePrincipal.ps1` →
     `powershell/internal/framework/` (folds the single-file `portal/` away)
   - `powershell/public/{cis,cisa,eidsca,maester,orca,xspm}` → `powershell/public/suites/`
   - `powershell/public/*.ps1` (root files) and `powershell/public/core/*` →
     `powershell/public/framework/`
2. `$PSScriptRoot` literal updates (the seven census files move depth 1 → 2; add one
   `../`): `Get-MtMaesterTestFolderPath.ps1`, `Get-MtMarkdownReport.ps1`,
   `Show-MtLogo.ps1`, `Get-MtRegistrableDomain.ps1`, `Send-MtMail.ps1`,
   `Send-MtTeamsMessage.ps1`, `Get-MtTestInventory.ps1`. The former `public/core/`
   files (e.g. `Get-MtHtmlReport.ps1`) stay at depth 2 — no edits.
3. Script edits (mechanical):
   - `build/Build-MaesterModule.ps1` L566 → `internal/suites/orca/orcaClass.psm1`;
     L579 → `"$SourceRoot/internal/suites/orca"`.
   - `build/orca/Update-OrcaTests.ps1` — output path → `powershell/internal/suites/orca/`.
   - `build/eidsca/Update-EidscaTests.ps1` — read path → `powershell/internal/suites/eidsca/`.
   - `build/Update-CommandReference.ps1:20` — replace the non-recursive two-path scan
     with a recursive scan of `./powershell/internal` (simpler and future-proof); make
     the `EditUrl` handling aware of `public/framework/` and `public/suites/`.
   - `website/scripts/generate-test-docs.mjs` — `internal/eidsca` walk →
     `internal/suites/eidsca`; regenerate `website/docs`.
   - `.coderabbit.yaml` — update path instructions that name `public/core`.
4. Compatibility notes: the ~240 ORCA `using module` references are same-directory and
   move with the folder; the dev loader and build enumeration are recursive and need
   nothing; `website/versioned_docs/` snapshots stay frozen (historical links resolve
   against release-tagged blobs).
5. **Validation gate:** `./build/Build-MaesterModule.ps1`, `./build/Test-MaesterModuleOutput.ps1`,
   and `./powershell/tests/pester.ps1` must pass **without modifying any assertions** —
   proof the shipped module is unchanged.

### Phase 3 — `tests/` → `maester-tests/` · rating: **safe with shim**; the old dev-heuristic branch is **needs-deprecation-period** · effort: M

1. `git mv tests maester-tests`.
2. Consumer edits:
   - `build/Build-MaesterModule.ps1` L40 → `"$PSScriptRoot/../maester-tests"` (the
     output name `module/maester-tests` already matches — no output change).
   - `powershell/public/framework/Invoke-Maester.ps1` dev heuristic — **shim**: key the
     new branch on `Test-Path './maester-tests'` (dev-repo root marker) and keep the
     old `./powershell/tests/pester.ps1`/`./tests` branch for one release cycle, then
     remove it. Keying on `./maester-tests` deliberately makes the sentinel independent
     of where the unit tests live, so Phase 4 needs no second sentinel change.
   - `powershell/public/framework/Get-MtTestInventory.ps1` — folder name `'tests'` →
     `'maester-tests'` and re-verify the default's behavior in the built module (its
     installed-context resolution looks questionable *today*; pre-existing, flag for a
     separate fix).
   - `.github/workflows/publish-tests.yaml` — `-ConfigPath ./maester-tests/maester-config.json`;
     `source-directory: ./maester-tests`. `target-directory: ./tests` is left alone —
     the future of the (unmaintained) `maester365/maester-tests` push is a separate
     decision, out of scope here.
   - `.github/workflows/build-validation.yaml` (and `build-website.yaml`) paths-filter
     `tests/**` → `maester-tests/**`.
   - `.github/CODEOWNERS` → `maester-tests/Maester/`, `maester-tests/EIDSCA/`,
     `maester-tests/cisa/` (also fixes the pre-existing `CISA` case mismatch).
   - `.gitignore:525` → `maester-tests/Custom/*.ps1`.
   - `website/scripts/generate-test-docs.mjs` — tests root + config path; regenerate.
   - `build/orca/Update-OrcaTests.ps1`, `build/eidsca/Update-EidscaTests.ps1` write
     paths; `build/Update-TagsDocumentation.ps1` default `$TestsPath`.
   - Sweep for stragglers: `Install-MaesterTests.ps1:9` help link, `powershell/README.md`,
     root `README.md`, `.github/` docs, and `website/docs` contributing pages.
3. Known, accepted quirk: an **older released module** run inside a **new checkout**
   still sentinels on `powershell/tests/pester.ps1` and targets the now-missing
   `./tests`. Maintainer-only impact — note it in the release changelog and announce
   the rename so open PRs touching `tests/**` rebase cleanly.

### Phase 4 — `powershell/{module, unit-tests}` split · rating: **safe with the Phase 3 shim in place** · effort: M

Run this **after** Phase 3 so the dev sentinel already keys on `./maester-tests`.

1. Moves:
   - `git mv` `powershell/{Maester.psd1,Maester.psm1,Maester.Format.ps1xml,README.md,assets,internal,public}`
     → `powershell/module/`.
   - `git mv powershell/tests powershell/unit-tests`.
   - `powershell/tools/` (placed by Phase 1) is deliberately **not** moved — it stays
     a sibling of `module/` and `unit-tests/`, since it ships outside the module.
2. **`.gitignore` first** (same commit): line 521 `module/` → `/module/` — the current
   pattern has no leading slash and would silently ignore `powershell/module/`;
   line 532 `powershell/maester-tests` → `powershell/module/maester-tests`.
3. Consumer edits:
   - `build/Build-MaesterModule.ps1` — `$SourceRoot` default → `../powershell/module`.
     Depth is computed relative to `$SourceRoot`, so no literal or depth-logic changes
     follow from this move by itself.
   - `powershell/unit-tests/pester.ps1` — `..\Maester.psd1` → `..\module\Maester.psd1`;
     coverage paths `..\public`/`..\internal` → `..\module\public`/`..\module\internal`.
     The `..\..\TestResults` output path is depth-unchanged and stays.
   - `.github/workflows/build-validation.yaml` — run `./powershell/unit-tests/pester.ps1`
     (both legs); the `powershell/**` paths-filter already covers the new layout.
   - `build/Update-CommandReference.ps1` — module import path and internal scan roots
     → `./powershell/module/...`.
   - `website/scripts/generate-test-docs.mjs` — `publicRoot`/`internalRoot` →
     `powershell/module/{public,internal}`.
   - `.vscode/launch.json:11` — `${workspaceFolder}/powershell/module/Maester.psd1`.
   - Contributor docs: `.github/pull_request_template.md`,
     `.github/skills/maester-test-expert/SKILL.md`, `website/docs/contributing.md` →
     `./powershell/unit-tests/pester.ps1`.
   - Sweep: grep `powershell/` across `build/` (legacy `Build-PSModule.ps1` /
     `azure-pipelines/` templates default to `.\powershell\` — update or mark legacy),
     `.github/`, and `website/docs`.
4. Compatibility notes: `Invoke-Maester.Tests.ps1` finds `smoketests/` relative to
   itself — moves with the tree, no edit. The Phase 3 sentinel shim already keys on
   `./maester-tests`, so no released-module regression beyond the one already accepted
   in Phase 3.
5. **Validation gate:** same as Phase 2 (build + output validation + full unit-test
   run), plus one manual `Invoke-Maester` smoke run from the repo root.

### Move-by-move safety summary

| Move | Rating |
| --- | --- |
| Move pipeline example → `docs/examples/` + move `tools/` → `powershell/tools/` | safe |
| Framework/suites split (incl. `portal/` fold, `core/` → `framework/`) | safe (shipped output identical) |
| `tests/` → `maester-tests/` | safe with shim |
| Keeping the old `./tests` heuristic branch, then removing it | needs-deprecation-period |
| `powershell/{module, unit-tests}` split | safe (with Phase 3 shim + `.gitignore` fix) |
| Renaming module **output** names (`module/maester-tests`, `OrcaClasses.ps1`, `assets/`) | **breaking — explicitly NOT proposed** |

### Never-change list (frozen contracts)

- **Build output layout:** `module/Maester.psd1`, `module/Maester.psm1`,
  `module/OrcaClasses.ps1`, `module/assets/`, `module/maester-tests/` (incl.
  `Custom/`) — asserted by `Test-MaesterModuleOutput.ps1` and resolved at runtime by
  `Get-MtMaesterTestFolderPath`. This is what installed users receive; it is
  independent of every source-tree move above.
- Exported function names and the one-function-per-file = filename rule the build's
  AST export generation depends on.
- `publish-tests.yaml` `target-directory: ./tests` is *left unchanged by this
  proposal* — not because the unmaintained `maester365/maester-tests` repo is a
  contract, but because deciding that push's future is out of scope here.

---

## Appendix A — Repository conventions (**PROPOSED / NOT YET RATIFIED**)

> Draft text to paste into AGENTS.md **after** the migration completes. Do not apply
> before Phase 4 lands.

```markdown
## Repository conventions

### Where files live (target state)

- `powershell/module/` — the complete PowerShell module source (`Maester.psd1`,
  `Maester.psm1`, `assets/`, `internal/`, `public/`). The build flattens this
  directory into the publishable artifact at `module/` (repo root, gitignored).
- `powershell/module/internal/framework/` — framework-private helpers only (session,
  Graph cache, config, progress, telemetry, portal links). If a helper exists to
  serve one test suite, it does NOT belong here.
- `powershell/module/internal/suites/<suite>/` — private helpers for one suite
  (defender, eidsca, orca, xspm). ORCA's `orcaClass.psm1` and `check-ORCA*.ps1` must
  stay together in `internal/suites/orca/` — the check files reference the class file
  by same-directory `using module`.
- `powershell/module/public/framework/` — exported framework surface
  (Connect/Invoke/report/config cmdlets).
- `powershell/module/public/suites/<suite>/` — exported suite-specific functions
  (cis, cisa, eidsca, maester/<workload>, orca, xspm).
- `powershell/unit-tests/` — unit tests for the module itself (`pester.ps1`,
  `general/`, `functions/`, and the `smoketests/` fixture that
  `Invoke-Maester.Tests.ps1` runs against). Never put security checks here.
- `powershell/tools/` — optional user-facing scripts that ship outside the module
  (e.g. `Save-MaesterOffline.ps1`). Not part of the build; not for build scripts
  (those go in `build/`).
- `maester-tests/<Suite>/` — Pester security checks shipped to end users; one tree,
  copied wholesale to `module/maester-tests/` at build time.
  `maester-tests/Custom/` is the user extension point and stays effectively empty
  in-repo. Never put unit tests here.
- `build/` — build, publish, and generator scripts. `website/` — Docusaurus site.
  `report/` — the report-template app. `module/` (repo root), `TestResults/`,
  `test-results/` — generated output; never commit.

### Naming and placement rules

- One exported function per file; the filename must equal the function name
  (the build's AST-based `FunctionsToExport` generation depends on this).
- Verb-Noun names with approved verbs; `Mt` prefix for framework nouns; suite checks
  follow their suite's ID scheme.
- PowerShell files are UTF-8 with BOM; OTBS; PascalCase; no aliases.
- Any `$PSScriptRoot/../…` literal must encode the file's real depth under
  `powershell/module/` — the module build strips exactly that many `../` when
  flattening. Files inside `internal/suites/<suite>/` or `public/suites/<suite>/`
  should avoid such literals entirely.
- Frozen names (never rename): the build-output layout (`module/maester-tests/`,
  `module/OrcaClasses.ps1`, `module/assets/`).
```

---

## Appendix B — Draft skill (**PROPOSED / NOT YET RATIFIED — not installed**)

> Draft for `.claude/skills/maester-repo-conventions/SKILL.md`, to be created only
> after the restructure is ratified and Phase 4 lands. Reproduced here for review;
> this proposal does not install it.

```markdown
---
name: maester-repo-conventions
description: >
  Apply when creating, moving, or renaming files in the maester monorepo, or when
  deciding where new code belongs: framework code vs suite-specific helper vs
  exported function vs security check vs unit test. Also apply before any change to
  build paths, workflow path filters, or directory names, to avoid breaking frozen
  packaging contracts.
---

# Maester repository placement rules

## Decision procedure for a new .ps1 file

1. Is it a Pester security check run against a tenant? → `maester-tests/<Suite>/`.
   Never under `powershell/`.
2. Is it a unit test for the module (or a fixture for one)? →
   `powershell/unit-tests/functions/` (or `general/` for repo-wide checks;
   `smoketests/` is a fixture consumed by Invoke-Maester.Tests.ps1). Never under
   `maester-tests/`.
3. Is it a standalone user-facing script that ships outside the module (offline
   installers, one-off utilities)? → `powershell/tools/`. Build scripts go in
   `build/` instead.
4. Is it a function used by exactly one suite (defender, eidsca, orca, xspm, cis,
   cisa, maester/<workload>)?
   - Exported → `powershell/module/public/suites/<suite>/`
   - Not exported → `powershell/module/internal/suites/<suite>/`
5. Otherwise it is framework code:
   - Exported → `powershell/module/public/framework/`
   - Not exported → `powershell/module/internal/framework/`

## Hard rules

- Filename = function name, one exported function per file (build generates
  `FunctionsToExport` from this via AST).
- Keep `internal/suites/orca/` intact: `check-ORCA*.ps1` files load
  `orcaClass.psm1` via same-directory `using module` — never split or rename
  within that directory without updating build/Build-MaesterModule.ps1 and
  build/orca/Update-OrcaTests.ps1.
- A `$PSScriptRoot/../…` literal must match the file's depth under
  `powershell/module/` (the build strips `../` × depth when flattening). Prefer no
  such literals in suite directories.
- Frozen contracts — never rename: the build-output layout `module/maester-tests/`,
  `module/OrcaClasses.ps1`, `module/assets/`.
- Generated trees (regenerate, don't hand-edit): `website/docs/tests/**`,
  `website/docs/commands/*.mdx`, `powershell/module/internal/suites/orca/check-ORCA*.ps1`,
  EIDSCA generated tests. `website/versioned_docs/**` is frozen history.
- Renaming or moving any directory listed in a workflow paths-filter
  (build-validation, build-website) requires updating the filter in the same PR.
- Gitignore patterns are path-sensitive: root-anchored ignores need a leading slash
  (`/module/`), or they match same-named directories at any depth.
```

---

*End of proposal. Feedback welcome — nothing in this document has been applied.*
