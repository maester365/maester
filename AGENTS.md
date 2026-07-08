# AGENTS.md

## Project overview

Maester is a PowerShell-based test automation framework for monitoring Microsoft 365 security
configuration. This monorepo contains the Maester PowerShell module source (`powershell/`), the
community security test suites shipped with it (`tests/`), the build scripts that assemble the
publishable module (`build/`), the Docusaurus documentation site (`website/`), and the React/Vite
project that produces the interactive HTML report template (`report/`).

## Repository map

- `powershell/` — module source. `Maester.psd1` (manifest), `Maester.psm1` (dev-time loader that
  dot-sources every `.ps1` under `internal/` and `public/`).
  - `powershell/internal/` — private helper functions, not exported. Per-suite subdirectories:
    `defender/`, `eidsca/`, `orca/`, `portal/`, `xspm/`.
  - `powershell/public/` — exported functions, one function per file named after the function.
    Subdirectories: `cis/`, `cisa/`, `core/`, `eidsca/`, `maester/`, `orca/`, `xspm/`.
  - `powershell/assets/` — static assets shipped with the module, including `ReportTemplate.html`.
  - `powershell/examples/` — sample multi-tenant pipeline YAML.
  - `powershell/tests/` — Pester unit tests for the module itself (see Test architecture).
- `tests/` — Maester security check suites installed to end-user tenants: `Maester/`, `EIDSCA/`,
  `cis/`, `cisa/`, `orca/`, `XSPM/`, `Custom/`, plus `maester-config.json`.
- `build/` — build, publish, and maintenance scripts (see Build and packaging).
- `website/` — Docusaurus 3 documentation site for maester.dev.
- `report/` — Vite + React + Tailwind project that builds the HTML report template.
- `.github/` — workflows, composite action `publish-maester-module`, CONTRIBUTING.md, issue templates.
- `action/` — deprecation notice only; the GitHub action moved to `maester365/maester-action`.
  Root `action.yml` still defines the legacy "Maester Action".
- `assets/` — repo logo images. `tools/` — `Save-MaesterOffline.ps1`.
- `module/` and `TestResults/` — gitignored build/test output; never commit them.

## Build and packaging

`./build/Build-MaesterModule.ps1` produces the publishable artifact in `./module/` (cleaned and
recreated each run; source tree is never modified). It:

- Concatenates all `powershell/internal/` and `powershell/public/` `.ps1` files into a single
  consolidated `Maester.psm1` (stripping file-level param blocks/attributes, rewriting
  `$PSScriptRoot/../` relative paths for the flattened layout).
- Consolidates ORCA class files (`internal/orca/orcaClass.psm1` + `check-ORCA*.ps1`) into
  `OrcaClasses.ps1`, referenced via `ScriptsToProcess` in the output manifest.
- Auto-generates `FunctionsToExport` by AST-parsing `powershell/public/` (a file's exported
  function must match its filename) and rewrites the output `Maester.psd1`.
- Copies `powershell/assets/`, `Maester.Format.ps1xml`, and `tests/` → `module/maester-tests/`.

`./build/Test-MaesterModuleOutput.ps1` validates the built module. The source manifest
`powershell/Maester.psd1` requires PowerShell 5.1+, Microsoft.Graph.Authentication ≥ 2.27.0, and
Pester. Publishing to the PowerShell Gallery happens in CI via
`.github/actions/publish-maester-module`.

## Test architecture

Two unrelated kinds of tests:

1. **Maester security checks** — `tests/` (Pester tests run against a tenant by `Invoke-Maester`).
   The build copies `tests/` into the module as `maester-tests/`
   (`build/Build-MaesterModule.ps1`, Phase G). At runtime, `Install-MaesterTests` /
   `Update-MaesterTests` (`powershell/public/core/`) call `Update-MtMaesterTests`
   (`powershell/internal/Update-MtMaesterTests.ps1`), which copies from the installed module's
   `maester-tests` folder (resolved by `powershell/internal/Get-MtMaesterTestFolderPath.ps1`) to
   the user's chosen directory, excluding `Custom/`. `publish-tests.yaml` also pushes `tests/` to
   the separate `maester365/maester-tests` repository on each release.
2. **Module unit tests** — `powershell/tests/`, run by `powershell/tests/pester.ps1`, which
   imports `powershell/Maester.psd1` and invokes Pester on `general/*.Tests.ps1` (manifest, help,
   PSScriptAnalyzer checks) and `functions/**/*.Tests.ps1`. Results go to `TestResults/`;
   `-Coverage` (or `PESTER_COVERAGE=true`) produces a JaCoCo report. Requires
   PSModuleDevelopment and PSFramework in addition to Pester.

## Website

Docusaurus 3 site in `website/` (Node 24, see `.nvmrc` / workflow configs). `npm run build` runs a
`prebuild` step, `node scripts/generate-test-docs.mjs`, which generates `website/docs/tests/` pages
from the markdown/tests in `tests/` and `tests/maester-config.json`. Command reference docs under
`website/docs/commands/` are generated from module comment-based help by
`build/Update-CommandReference.ps1` using the Alt3.Docusaurus.Powershell module
(`New-DocusaurusHelp`); CI runs it via `update-module-docs.yaml` / `build-docs.yaml` and opens a PR.

## Report generator

`report/` is a Vite + React + Tremor/Tailwind app. `npm run build` (tsc + vite with
`vite-plugin-singlefile`) emits a single-file `report/dist/index.html`. CI
(`build-maester-report-template.yaml`) copies it to `powershell/assets/ReportTemplate.html`. At
runtime `Get-MtHtmlReport` (`powershell/public/core/Get-MtHtmlReport.ps1`) reads that template and
splices the test-results JSON into it in place of an embedded placeholder object.

## Commands

- Build module: `./build/Build-MaesterModule.ps1` (output in `./module/`)
- Validate built module: `./build/Test-MaesterModuleOutput.ps1`
- Run unit tests: `./powershell/tests/pester.ps1` (add `-Coverage` for JaCoCo coverage)
- PSScriptAnalyzer: runs inside the unit-test suite
  (`powershell/tests/general/PSScriptAnalyzer.Tests.ps1`, all rules except
  `PSAvoidTrailingWhitespace` and `PSShouldProcess` against `public/` and `internal/`); CI also
  runs `microsoft/psscriptanalyzer-action` over the whole repo (`psscriptanalyzer.yml`)
- Website: `cd website && npm ci && npm start` (preview) / `npm run build`;
  regenerate test docs with `npm run generate-test-docs` (verify with `npm run check-test-docs`)
- Report template: `cd report && npm ci && npm run build` (or `npm run dev`)

## CI/CD (.github/workflows/)

- `build-validation.yaml` — PR/dispatch: Pester unit tests on a Linux/Windows matrix (pwsh +
  Windows PowerShell), coverage on the Linux leg, then builds and validates the module.
- `build-validation-report.yaml` — posts test results after build-validation completes.
- `build-maester-report-template.yaml` — reusable: builds `report/` and uploads the updated
  `ReportTemplate.html` artifact when changed.
- `build-website.yaml` — reusable: regenerates command reference and builds the Docusaurus site.
- `build-docs.yaml` / `update-module-docs.yaml` — run `Update-CommandReference.ps1` and open a PR.
- `publish-module.yaml` — manual: version bump, build, validate, publish to PowerShell Gallery,
  GitHub release, website version update.
- `publish-module-preview.yaml` — same pipeline as a preview release on push to main.
- `publish-module-manualversionupdate.yaml` — manual publish after a manual version update.
- `publish-tests.yaml` — on release: pushes `tests/` to the `maester365/maester-tests` repo.
- `publish-versioned-docs.yml` — manual: creates a versioned docs snapshot on the website.
- `update-tag-documentation.yml` — regenerates tag documentation.
- `update-public-suffix-list.ps1` / `update-role-definitions.yaml` — scheduled data refreshes
  (public suffix list; Entra role definitions).
- `psscriptanalyzer.yml`, `codeql.yml`, `opengrep.yml`, `scorecard.yml`,
  `dependency-review.yaml` — static analysis and supply-chain security scans.

## Conventions

From `.github/CONTRIBUTING.md`: One True Brace Style (OTBS); PascalCase names; full cmdlet names
(no aliases); comment-based help inside function blocks with synopsis, description, and examples.
Never edit or commit `./module/`. From `.vscode/settings.json`: PowerShell files use UTF-8 with
BOM (enforced by the `PSUseBOMForUnicodeEncodedFile` analyzer rule); format on save; trim trailing
whitespace. Spell-checking configured in `.cspell.json`. No `.editorconfig` exists at the repo
root. Public functions live one-per-file with the filename matching the function name — the build
warns and skips exports otherwise.

## AI tooling conventions

- `AGENTS.md` (this file) is the canonical, tool-agnostic agent context. `CLAUDE.md` is a thin
  bridge that imports it (via `@AGENTS.md`) because Claude Code reads `CLAUDE.md`, not `AGENTS.md`.
- `.github/agents/` holds the canonical agent definitions (`*.agent.md`); `.claude/agents/`
  (Markdown) and `.codex/agents/` (TOML) are tool-specific projections of those definitions.
- Skills live in `.github/skills/` (canonical) and `.claude/skills/`.
