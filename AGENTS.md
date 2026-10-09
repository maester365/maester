# AGENTS.md

Maester is a PowerShell framework for monitoring Microsoft 365 security
configuration, with its own test engine. Pester is used only for the module's unit tests
and to run users' Pester-format custom tests. Requires PowerShell 7.4+. Monorepo: `powershell/` (module source),
`tests/` (security checks shipped to users), `src/Maester.Engine/` (C# engine core,
built DLL committed in `powershell/lib/`), `build/`, `website/` (Docusaurus,
maester.dev), `report/` (React app that builds the HTML report template).

## Two unrelated test trees — don't mix them

- `tests/` — Maester **security checks** that ship to end-user tenants, run via
  `Invoke-Maester`. Each check is a native test: `tests/<suite>/[<service>/]Test.<ID>.ps1`
  (one function with a `[MaesterTest(...)]` attribute) plus `Test.<ID>.md`. No
  `*.Tests.ps1` wrappers, no connection/licence guards, no outer try/catch: declare
  `Service`/`License` and the engine handles them. Scaffold with `New-MtTest`,
  validate with `Get-MtTest -Path`, run with `Invoke-MtTest -Path`; `Convert-MtTest`
  converts users' Pester-format tests. New MT.xxxx checks go here; follow
  `.github/skills/maester-test-expert/SKILL.md` and `website/docs/writing-tests/index.mdx`.
- `powershell/tests/` — **unit tests for the module itself**.

## Commands

- Unit tests: `./powershell/tests/pester.ps1` — run before pushing. These enforce
  naming, exports, help, and PSScriptAnalyzer conventions; fix what they flag.
- Build module: `./build/Build-MaesterModule.ps1`; validate: `./build/Test-MaesterModuleOutput.ps1`
- Website: `cd website && npm ci && npm start` · Report: `cd report && npm ci && npm run build`

## Hard rules

- Generated content — regenerate, never hand-edit: `website/docs/commands/`,
  `website/docs/tests/`, `website/versioned_docs/`, everything under
  `powershell/internal/generated/`, and the native `tests/eidsca/Test.EIDSCA.*` and
  `tests/orca/Test.ORCA.*` files the generators in `build/eidsca/` and `build/orca/`
  write. Edit the PowerShell source, comment-based help or generator templates and let
  automation regenerate.

## Repository layout — where files go

Full rules and reasoning: `website/docs/contributing.md` ("Repository layout"), published at
https://maester.dev/docs/next/contributing#repository-layout. `powershell/tests/general/RepositoryLayout.Tests.ps1`
enforces them. When writing or reviewing a change, check every added, moved or renamed file:

- Folder names under `tests/`, `powershell/` and `build/` are lowercase kebab-case
  (`global-secure-access`, not `GlobalSecureAccess`). No two paths may differ only in case.
- One name per service, the same everywhere: `ad`, `azure`, `azure-devops`, `copilot`,
  `copilot-studio`, `defender`, `entra`, `exchange`, `foundry`, `github`,
  `global-secure-access`, `graph`, `intune`, `purview`, `sharepoint`, `teams`, `xspm`.
  Folders name the product whose settings a check reads, never a theme: an AI check goes in
  the folder of its product (an Entra agent identity check in `entra/`) and carries the `AI`
  tag. A new service must be added to the guide and the test.
- `tests/<suite>/` holds only `Test.<ID>.ps1`, `Test.<ID>.md`, `suite.json` and `README.md`.
  Suites: `maester/<service>/` (plus `drift/`; `maester/xspm/` has its own suite.json),
  `cis/`, `cisa/<service>/`, `ad/<area>/`, generated `eidsca/` and `orca/`, and `custom/`
  (reserved for users; never commit tests there).
- `powershell/public/` (exported) is grouped by job: `run/`, `connect/`, `report/`, `app/`,
  `services/<service>/`. `powershell/internal/` uses `engine/`, `session/`, `connect/`,
  `report/`, `app/`, `services/<service>/`, `checks/<suite>/<service>/`, `generated/`,
  `utility/`. Nothing sits directly in `public/` or `internal/`.
- Put a function by its job, not by the check that first needed it: reusable data access
  for a service goes in `internal/services/<service>/`; logic only one suite's checks use
  goes in `internal/checks/<suite>/<service>/`; a helper users call from custom tests goes
  in `public/services/<service>/` (and in the manifest's `FunctionsToExport`).
- One function per file, named `Verb-Noun.ps1` after the function, with an approved verb.
- Custom tests can call only exported commands. To make an internal helper available to them,
  `git mv` it from `internal/services/<service>/` to `public/services/<service>/`, add it to
  `FunctionsToExport`, and give it full comment-based help (see "Making an internal helper public"
  in the contributing guide). Exporting a command makes it public API; flag a promotion in review.
