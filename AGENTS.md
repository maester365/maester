# AGENTS.md

Maester is a PowerShell + Pester framework for monitoring Microsoft 365 security
configuration. Monorepo: `powershell/` (module source), `tests/` (security checks
shipped to users), `build/`, `website/` (Docusaurus, maester.dev), `report/`
(React app that builds the HTML report template).

## Two unrelated test trees — don't mix them

- `tests/` — Maester **security checks** that ship to end-user tenants, run via
  `Invoke-Maester`. New MT.xxxx checks go here; follow
  `.github/skills/maester-test-expert/SKILL.md`.
- `powershell/tests/` — **unit tests for the module itself**.

## Commands

- Unit tests: `./powershell/tests/pester.ps1` — run before pushing. These enforce
  naming, exports, help, and PSScriptAnalyzer conventions; fix what they flag.
- Build module: `./build/Build-MaesterModule.ps1`; validate: `./build/Test-MaesterModuleOutput.ps1`
- Website: `cd website && npm ci && npm start` · Report: `cd report && npm ci && npm run build`

## Hard rules

- Generated content — regenerate, never hand-edit: `website/docs/commands/`,
  `website/docs/tests/`, `website/versioned_docs/`,
  `powershell/internal/orca/check-ORCA*.ps1`, EIDSCA generated tests. Edit the
  PowerShell source or comment-based help and let automation regenerate.
