# AGENTS.md

Maester is a PowerShell framework for monitoring Microsoft 365 security
configuration, with its own test engine. Pester is used only for the module's unit tests
and to run users' Pester-format custom tests. Requires PowerShell 7.4+. Monorepo: `powershell/` (module source),
`tests/` (security checks shipped to users), `src/Maester.Engine/` (C# engine core,
built DLL committed in `powershell/lib/`), `build/`, `website/` (Docusaurus,
maester.dev), `report/` (React app that builds the HTML report template).

## Two unrelated test trees — don't mix them

- `tests/` — Maester **security checks** that ship to end-user tenants, run via
  `Invoke-Maester`. Each check is a native test: `tests/<suite>/[<area>/]Test.<ID>.ps1`
  (one function with a `[MaesterTest(...)]` attribute) plus `Test.<ID>.md`. No
  `*.Tests.ps1` wrappers, no connection/licence guards, no outer try/catch: declare
  `Service`/`CompatibleLicense` and the engine handles them. Scaffold with `New-MtTest`,
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
  `website/docs/tests/`, `website/versioned_docs/`,
  `powershell/internal/orca/check-ORCA*.ps1`, EIDSCA generated tests (and the
  native `tests/EIDSCA/Test.EIDSCA.*` and `tests/orca/Test.ORCA.*` files the
  generators in `build/eidsca/` and `build/orca/` write). Edit the PowerShell
  source, comment-based help or generator templates and let automation regenerate.
